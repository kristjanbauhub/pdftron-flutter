package com.pdftron.pdftronflutter.bauhub;

import android.os.Handler;
import android.os.Looper;
import android.view.MotionEvent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.pdftron.common.PDFNetException;
import com.pdftron.pdf.Annot;
import com.pdftron.pdf.PDFDoc;
import com.pdftron.pdf.PDFViewCtrl;
import com.pdftron.pdf.Point;
import com.pdftron.pdf.controls.OnToolbarStateUpdateListener;
import com.pdftron.pdf.model.AnnotStyle;
import com.pdftron.pdf.tools.AdvancedShapeCreate;
import com.pdftron.pdf.tools.PolygonCreate;
import com.pdftron.pdf.tools.ToolManager;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;

/**
 * Polygon markup with Bauhub styling. Stock {@link PolygonCreate} init only — see {@link BauhubAreaMarkupTool}.
 *
 * <p>Also acts as the native owner of the shape-tool <b>state</b> channel used by the Flutter
 * polygon-commit UI (Cancel / Undo / Redo / Done). The stock PDFTron edit toolbar is suppressed
 * (see {@link #onUp}); in its place the Flutter widget renders its own chrome driven by the
 * {@link #setStateEventSink(EventChannel.EventSink) sink} published here.
 */
public class BauhubPolygonMarkupTool extends PolygonCreate {

    public static final ToolManager.ToolModeBase MODE =
            ToolManager.ToolMode.addNewMode(Annot.e_Polygon);

    /**
     * Singleton event-sink used to broadcast in-progress polygon state (vertex count, undo/redo
     * availability) to Dart. We stash it on the class rather than routing through
     * {@code ViewerComponent} to avoid touching every widget/fullscreen wiring file for a feature
     * that's Bauhub-only. Registered in {@code PluginMethodCallHandler} and {@code FlutterDocumentView}.
     */
    private static volatile EventChannel.EventSink sStateEventSink;

    /**
     * Weak-ref to the currently active tool so the method-channel handlers can drive
     * cancel/undo/redo without having to re-fetch from {@code ToolManager} (which may have
     * already swapped tools in some races).
     */
    private static WeakReference<BauhubPolygonMarkupTool> sActiveTool = new WeakReference<>(null);

    private String bauhubSubject = "Comment";
    private final Handler mMainHandler = new Handler(Looper.getMainLooper());

    public BauhubPolygonMarkupTool(@NonNull PDFViewCtrl ctrl) {
        super(ctrl);
        mHasFill = false;
        BauhubShapeMarkupStyle.syncShapeCreationStyleToToolStyleConfig(ctrl.getContext());

        sActiveTool = new WeakReference<>(this);
        setOnToolbarStateUpdateListener(new OnToolbarStateUpdateListener() {
            @Override
            public void onToolbarStateUpdated() {
                emitStateSnapshot();
            }
        });
        // Emit an initial "no vertices" snapshot so Dart knows the tool is live and Point/Area
        // can remain visible until the first tap.
        mMainHandler.post(this::emitStateSnapshot);
    }

    public void configure(String subject) {
        this.bauhubSubject = subject != null ? subject : "Comment";
    }

    /** @see BauhubAreaMarkupTool#getBauhubShapeCreationPageNum() */
    public int getBauhubShapeCreationPageNum() {
        return mDownPageNum;
    }

    @Override
    public boolean onDown(MotionEvent e) {
        AnnotStyle style = new AnnotStyle();
        BauhubShapeMarkupStyle.configureRubberBandAnnotStyle(style, Annot.e_Polygon);
        setupAnnotProperty(style);
        return super.onDown(e);
    }

    /**
     * Bypass the zombie-annotation crash that silently breaks polygon vertex placement.
     *
     * <p>{@link AdvancedShapeCreate#onUp} calls a private {@code canSelectTool(MotionEvent)} on every
     * tap. The stock implementation hit-tests the tap location via
     * {@code ToolManager.getAnnotationAt} → {@code AnnotUtils.hasPermission} → {@code Annot.isMarkup},
     * which throws {@code "Operation on invalid object"} against any stale Annot wrapper (a "zombie"
     * left behind by a prior {@code page.annotRemove} that invalidated the Java wrapper but left its
     * pointer in PDFTron's native hit-test cache). The throw is swallowed inside {@code hasPermission},
     * so {@code canSelectTool} returns {@code true} and {@code onUp} exits WITHOUT adding the vertex —
     * polygon drawing silently dies while {@code System.err} floods with the crash stack.
     *
     * <p>{@link com.pdftron.pdf.tools.RectCreate} (parent of {@link BauhubAreaMarkupTool}) extends
     * {@link com.pdftron.pdf.tools.SimpleShapeCreate}, whose {@code onUp} never calls
     * {@code canSelectTool}, which is why the rectangle tool is unaffected by the exact same zombie.
     *
     * <p>The private {@code canSelectTool(MotionEvent)} method isn't overridable from outside
     * {@code com.pdftron.pdf.tools}, but it short-circuits and returns {@code false} the moment
     * {@link AdvancedShapeCreate#mIsEditToolbarShown} is {@code true}. Pre-setting that flag to
     * {@code true} before {@code super.onUp} therefore bypasses {@code getAnnotationAt} entirely
     * and never even creates the opportunity for a zombie to crash the hit-test. The side effect
     * ({@code showEditToolbar} becomes a no-op because it also checks {@code mIsEditToolbarShown})
     * is desired here — Bauhub surfaces its own "Valmis" FAB to commit the polygon and never wants
     * PDFTron's default edit toolbar.
     */
    @Override
    public boolean onUp(MotionEvent e, PDFViewCtrl.PriorEventMode priorEventMode) {
        mIsEditToolbarShown = true;
        return super.onUp(e, priorEventMode);
    }

    @Override
    public void setupAnnotProperty(AnnotStyle annotStyle) {
        BauhubShapeMarkupStyle.configureRubberBandAnnotStyle(annotStyle, Annot.e_Polygon);
        super.setupAnnotProperty(annotStyle);
    }

    @Override
    public ToolManager.ToolModeBase getToolMode() {
        return MODE;
    }

    @Override
    protected Annot createMarkup(PDFDoc doc, ArrayList<Point> pagePoints) throws PDFNetException {
        Annot annot = super.createMarkup(doc, pagePoints);
        BauhubShapeMarkupStyle.apply(this, annot, bauhubSubject);
        BauhubShapeMarkupStyle.scheduleDeferredAreaMarkupStyleReapply(this, annot, bauhubSubject);
        // Commit clears the vertex buffer; let the UI collapse its polygon-active bar.
        emitDetachedStateSnapshot();
        return annot;
    }

    @Override
    public void onClose() {
        super.onClose();
        // Tool torn down (user switched tools / closed doc / cancelled). Reset Dart-side state.
        if (sActiveTool.get() == this) {
            sActiveTool = new WeakReference<>(null);
        }
        emitDetachedStateSnapshot();
    }

    // region — Dart-facing API (called from PluginUtils)

    /**
     * Registers the sink the tool will push state snapshots into. Null unregisters.
     */
    public static void setStateEventSink(@Nullable EventChannel.EventSink sink) {
        sStateEventSink = sink;
    }

    /** Returns the active tool instance or {@code null} if no Bauhub polygon is in progress. */
    @Nullable
    public static BauhubPolygonMarkupTool getActiveTool() {
        return sActiveTool.get();
    }

    /**
     * Drops the in-progress polygon (discards all vertices + redo stack) and switches the
     * viewer back to the {@code PAN} tool so subsequent taps stop dropping vertices. Mirrors
     * iOS's {@code [BauhubPolygonMarkupTool cancelActiveShape]}.
     *
     * <p>{@link ToolManager#backToDefaultTool()} alone is unreliable here: the "default tool"
     * is whatever was active before {@code BauhubPolygonMarkupTool} took over, which in the
     * Bauhub flow is {@code BauhubPolygonMarkupTool} itself (Flutter calls {@code setToolMode}
     * once and never resets it). It would happily reinstate the polygon tool and we'd be right
     * back to the bug. Build a fresh {@code PAN} instance and {@code setTool} it explicitly —
     * matching the pattern already used in {@code PluginUtils#setToolMode}.
     *
     * <p>The {@code setTool} hop must run on the UI thread; PDFTron asserts this internally and
     * will silently no-op (or worse, crash) when called off-main.
     */
    public static boolean cancelActiveShape() {
        final BauhubPolygonMarkupTool active = sActiveTool.get();
        if (active == null) {
            return false;
        }
        if (active.canClear()) {
            active.clear();
        }
        active.mMainHandler.post(() -> {
            try {
                PDFViewCtrl ctrl = active.mPdfViewCtrl;
                if (ctrl == null) return;
                Object raw = ctrl.getToolManager();
                if (!(raw instanceof ToolManager)) return;
                ToolManager tm = (ToolManager) raw;
                tm.setTool(tm.createTool(ToolManager.ToolMode.PAN, tm.getTool()));
            } catch (Throwable ignored) {
                // Tool manager may be torn down (doc closed mid-cancel); silently fall through.
            }
        });
        // Tool swap will fire onClose -> emitDetachedStateSnapshot. Push an immediate detached
        // snapshot too so the Flutter bar collapses without waiting for the post to flush.
        active.emitDetachedStateSnapshot();
        return true;
    }

    /** Pops the most recent vertex from the in-progress polygon, if any. */
    public static boolean undoActiveShapePoint() {
        BauhubPolygonMarkupTool active = sActiveTool.get();
        if (active == null || !active.canUndo()) {
            return false;
        }
        active.undo();
        active.emitStateSnapshot();
        return true;
    }

    /** Re-applies the most recently undone vertex to the in-progress polygon, if any. */
    public static boolean redoActiveShapePoint() {
        BauhubPolygonMarkupTool active = sActiveTool.get();
        if (active == null || !active.canRedo()) {
            return false;
        }
        active.redo();
        active.emitStateSnapshot();
        return true;
    }

    // endregion

    private void emitStateSnapshot() {
        final EventChannel.EventSink sink = sStateEventSink;
        if (sink == null) return;
        final Map<String, Object> payload = new HashMap<>();
        payload.put("active", true);
        payload.put("vertexCount", mPagePoints == null ? 0 : mPagePoints.size());
        payload.put("canUndo", canUndo());
        payload.put("canRedo", canRedo());
        mMainHandler.post(() -> {
            try {
                sink.success(payload);
            } catch (Throwable ignored) {
                // sink can be torn down between the post and the delivery; tolerate it silently.
            }
        });
    }

    /** Emit a snapshot describing "no polygon in progress" (tool closed / committed). */
    private void emitDetachedStateSnapshot() {
        final EventChannel.EventSink sink = sStateEventSink;
        if (sink == null) return;
        final Map<String, Object> payload = new HashMap<>();
        payload.put("active", false);
        payload.put("vertexCount", 0);
        payload.put("canUndo", false);
        payload.put("canRedo", false);
        mMainHandler.post(() -> {
            try {
                sink.success(payload);
            } catch (Throwable ignored) {
            }
        });
    }
}
