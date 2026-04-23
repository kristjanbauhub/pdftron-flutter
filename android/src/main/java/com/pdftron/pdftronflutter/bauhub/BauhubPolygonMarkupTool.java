package com.pdftron.pdftronflutter.bauhub;

import android.view.MotionEvent;

import androidx.annotation.NonNull;

import com.pdftron.common.PDFNetException;
import com.pdftron.pdf.Annot;
import com.pdftron.pdf.PDFDoc;
import com.pdftron.pdf.PDFViewCtrl;
import com.pdftron.pdf.Point;
import com.pdftron.pdf.model.AnnotStyle;
import com.pdftron.pdf.tools.AdvancedShapeCreate;
import com.pdftron.pdf.tools.PolygonCreate;
import com.pdftron.pdf.tools.ToolManager;

import java.util.ArrayList;

/**
 * Polygon markup with Bauhub styling. Stock {@link PolygonCreate} init only — see {@link BauhubAreaMarkupTool}.
 */
public class BauhubPolygonMarkupTool extends PolygonCreate {

    public static final ToolManager.ToolModeBase MODE =
            ToolManager.ToolMode.addNewMode(Annot.e_Polygon);

    private String bauhubSubject = "Comment";

    public BauhubPolygonMarkupTool(@NonNull PDFViewCtrl ctrl) {
        super(ctrl);
        mHasFill = false;
        BauhubShapeMarkupStyle.syncShapeCreationStyleToToolStyleConfig(ctrl.getContext());
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
        return annot;
    }
}
