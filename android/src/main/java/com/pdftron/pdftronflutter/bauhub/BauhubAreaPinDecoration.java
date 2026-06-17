package com.pdftron.pdftronflutter.bauhub;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.pdftron.common.PDFNetException;
import com.pdftron.pdf.Annot;
import com.pdftron.pdf.PDFDoc;
import com.pdftron.pdf.PDFViewCtrl;
import com.pdftron.pdf.Page;
import com.pdftron.pdf.Rect;
import com.pdftron.pdf.annots.Markup;
import com.pdftron.pdf.tools.BauhubToolsAccess;
import com.pdftron.pdf.tools.Tool;
import com.pdftron.pdf.tools.ToolManager;
import com.pdftron.pdf.utils.AnalyticsHandlerAdapter;
import com.pdftron.pdftronflutter.R;
import com.pdftron.sdf.Obj;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

/**
 * Decorative pin stamps for Comment / Attachment / Task square and polygon markups — same image
 * scaling and placement as {@link BauhubPinStampTool}. Stamps are {@link Annot#e_locked} and tagged
 * with {@link #DECORATIVE_STAMP_CUSTOM_KEY} so they are not meant to be edited; taps may still
 * hit-test depending on the viewer (locked reduces moves/resizes).
 */
public final class BauhubAreaPinDecoration {

    public static final String CUSTOM_DATA_KEY = "BauhubAreaPin";
    public static final String DECORATIVE_STAMP_CUSTOM_KEY = "BauhubDecorativeAreaPin";
    /** Decorative stamp stores the parent square/polygon {@link com.pdftron.pdf.Annot#getUniqueID()} text for cleanup. */
    public static final String PARENT_SHAPE_UID_KEY = "BauhubParentShapeUid";

    private static final double PAD = 4.0;

    private BauhubAreaPinDecoration() {
    }

    /**
     * Mirrors a parent shape's hide/show onto every linked decorative pin stamp on the same
     * page. Activity-feed filters (type toggles + "Näita lahendatud") use this so a hidden
     * comment / attachment / task area never leaves its corner pin floating on the canvas.
     *
     * <p>Looks up the parent's {@link Annot#getUniqueID()}, scans the page for stamps with
     * {@link #DECORATIVE_STAMP_CUSTOM_KEY} + {@link #PARENT_SHAPE_UID_KEY} equal to the
     * parent uid, and calls {@link PDFViewCtrl#hideAnnotation(Annot)} /
     * {@link PDFViewCtrl#showAnnotation(Annot)} for each match. Pure point-pin annotations
     * (no parent shape) have no decorative stamps attached and short-circuit out via the
     * subject check inside {@link #bauhubAreaParentUidFromShapeAnnot}; the hide/show in
     * {@code PluginUtils} for those takes care of the pin directly.
     *
     * <p>Caller must already hold the doc write-lock and is responsible for invoking
     * {@link PDFViewCtrl#update(Annot, int)} (or a broader update) once after the operation.
     */
    public static void setDecorativePinsVisibilityForParentShape(
            @NonNull PDFViewCtrl pdfViewCtrl,
            @NonNull PDFDoc doc,
            @NonNull Annot shapeAnnot,
            int pageNum,
            boolean visible) {
        try {
            String parentUid = bauhubAreaParentUidFromShapeAnnot(shapeAnnot);
            if (parentUid == null || parentUid.isEmpty()) {
                return;
            }
            if (pageNum < 1) {
                pageNum = resolvePageNumberForShapeAnnot(pdfViewCtrl, doc, shapeAnnot);
            }
            if (pageNum < 1) {
                return;
            }
            Page page = doc.getPage(pageNum);
            if (page == null) {
                return;
            }
            int n = page.getNumAnnots();
            for (int i = 0; i < n; i++) {
                Annot a = page.getAnnot(i);
                if (a == null || !a.isValid() || a.getType() != Annot.e_Stamp) {
                    continue;
                }
                String dec = null;
                try {
                    dec = a.getCustomData(DECORATIVE_STAMP_CUSTOM_KEY);
                } catch (Exception ignored) {
                }
                if (dec == null || dec.isEmpty()) {
                    continue;
                }
                String puid = null;
                try {
                    puid = a.getCustomData(PARENT_SHAPE_UID_KEY);
                } catch (Exception ignored) {
                }
                if (!parentUid.equals(puid)) {
                    continue;
                }
                if (visible) {
                    pdfViewCtrl.showAnnotation(a);
                } else {
                    pdfViewCtrl.hideAnnotation(a);
                }
            }
        } catch (Exception e) {
            AnalyticsHandlerAdapter.getInstance().sendException(e);
        }
    }

    /**
     * Removes decorative area-pin stamps whose {@link #PARENT_SHAPE_UID_KEY} matches (e.g. shape was deleted).
     */
    public static void removeDecorativeStampsForParentUid(
            @NonNull PDFViewCtrl ctrl, @NonNull PDFDoc doc, int pageNum, @Nullable String parentUid) {
        if (parentUid == null || parentUid.isEmpty() || pageNum < 1) {
            return;
        }
        try {
            Page page = doc.getPage(pageNum);
            int n = page.getNumAnnots();
            ArrayList<Annot> remove = new ArrayList<>();
            for (int i = 0; i < n; i++) {
                Annot a = page.getAnnot(i);
                if (a == null || !a.isValid() || a.getType() != Annot.e_Stamp) {
                    continue;
                }
                String dec = null;
                try {
                    dec = a.getCustomData(DECORATIVE_STAMP_CUSTOM_KEY);
                } catch (Exception ignored) {
                }
                if (dec == null || dec.isEmpty()) {
                    continue;
                }
                String puid = null;
                try {
                    puid = a.getCustomData(PARENT_SHAPE_UID_KEY);
                } catch (Exception ignored) {
                }
                if (parentUid.equals(puid)) {
                    remove.add(a);
                }
            }
            for (Annot a : remove) {
                try {
                    page.annotRemove(a);
                } catch (Exception ignored) {
                }
            }
            if (!remove.isEmpty()) {
                ctrl.update(true);
            }
        } catch (Exception e) {
            AnalyticsHandlerAdapter.getInstance().sendException(e);
        }
    }

    @Nullable
    private static String bauhubAreaParentUidFromShapeAnnot(@NonNull Annot shapeAnnot) throws PDFNetException {
        if (!shapeAnnot.isValid() || !shapeAnnot.isMarkup()) {
            return null;
        }
        int t = shapeAnnot.getType();
        if (t != Annot.e_Square && t != Annot.e_Polygon) {
            return null;
        }
        Markup m = new Markup(shapeAnnot);
        String subj = m.getSubject();
        if (subj == null
                || (!"Comment".equals(subj)
                        && !"Attachment".equals(subj)
                        && !"Task".equals(subj))) {
            return null;
        }
        Obj uidObj = shapeAnnot.getUniqueID();
        if (uidObj == null) {
            return null;
        }
        try {
            String parentUid = uidObj.getAsPDFText();
            if (parentUid == null || parentUid.isEmpty()) {
                return null;
            }
            return parentUid;
        } catch (Exception ignored) {
            return null;
        }
    }

    /**
     * When a Bauhub area square/polygon is removed (e.g. user cancels the add-comment flow), remove matching
     * decorative pin stamps so they do not linger on the page.
     */
    public static void removeDecorativePinsForParentShapeRemoval(
            @NonNull PDFViewCtrl ctrl,
            @NonNull PDFDoc doc,
            @NonNull Annot shapeAnnot,
            int pageNum) {
        try {
            String parentUid = bauhubAreaParentUidFromShapeAnnot(shapeAnnot);
            if (parentUid == null) {
                return;
            }
            if (pageNum < 1) {
                pageNum = BauhubAreaPinDecoration.resolvePageNumberForShapeAnnot(ctrl, doc, shapeAnnot);
            }
            if (pageNum < 1) {
                return;
            }
            removeDecorativeStampsForParentUid(ctrl, doc, pageNum, parentUid);
        } catch (Exception e) {
            AnalyticsHandlerAdapter.getInstance().sendException(e);
        }
    }

    public static void decorateAllMatchingShapes(@NonNull PDFViewCtrl pdfViewCtrl, @NonNull PDFDoc doc) throws PDFNetException {
        int pageCount = doc.getPageCount();
        for (int p = 1; p <= pageCount; p++) {
            Page page = doc.getPage(p);
            int n = page.getNumAnnots();
            ArrayList<Annot> targets = new ArrayList<>();
            for (int i = 0; i < n; i++) {
                Annot a = page.getAnnot(i);
                if (a == null || !a.isValid()) {
                    continue;
                }
                // Do not skip based on BauhubAreaPin custom data alone — same as iOS
                // BauhubDecorateAllImportedAreaPins: XFDF/server flows can keep the flag on the shape while the
                // decorative stamp annot never persisted (or was stripped). We still run applyPinForShapeAnnot;
                // dedupe uses a linked decorative stamp + geometry, not CUSTOM_DATA_KEY on the shape.
                if (!matchesBauhubShape(a)) {
                    continue;
                }
                targets.add(a);
            }
            for (Annot shape : targets) {
                applyPinForShapeAnnot(pdfViewCtrl, doc, p, shape, null);
            }
        }
        pdfViewCtrl.update(true);
    }

    public static void ensurePinForNewShape(@NonNull Tool tool, @NonNull Annot shapeAnnot) throws PDFNetException {
        if (!shapeAnnot.isValid() || alreadyHasPin(shapeAnnot)) {
            return;
        }
        PDFViewCtrl ctrl = BauhubToolsAccess.getPdfViewCtrl(tool);
        if (ctrl == null) {
            return;
        }
        PDFDoc doc = ctrl.getDoc();
        // Place the pin ONLY after the shape is on the page's {@code Annots} array. The parent tool
        // (e.g. {@link com.pdftron.pdf.tools.RectCreate} / {@link com.pdftron.pdf.tools.PolygonCreate})
        // appends the shape inside its {@code createMarkup}/commit flow, so placing the stamp
        // synchronously from here races and lands the stamp BEFORE the shape — forcing an in-place
        // reorder via {@code page.annotRemove + annotPushBack} that leaves a stale pointer in
        // PDFTron's native hit-test cache (zombie Annot: {@code ToolManager.getAnnotationAt} →
        // {@code AnnotUtils.hasPermission} → {@code Annot.isMarkup} throws "Operation on invalid
        // object", crashing {@code Pan.selectAnnot}, {@code AnnotEdit.onSingleTapConfirmed}, and
        // {@code AdvancedShapeCreate.canSelectTool}). Deferring to {@code ctrl.post} runs on the
        // next UI loop tick — by then the shape is on the page and the stamp is simply appended
        // at the end, above the shape, with no reorder and no zombie.
        Runnable placePin = () -> {
            runUnderDocWriteLock(ctrl, () -> {
                try {
                    if (!shapeAnnot.isValid() || alreadyHasPin(shapeAnnot)) {
                        return;
                    }
                    tryPlacePinForShape(ctrl, doc, shapeAnnot, tool);
                } catch (Exception e) {
                    AnalyticsHandlerAdapter.getInstance().sendException(e);
                }
            });
            // Second pass fallback: {@link Annot#getPage} may still lag one tick on multi-page
            // continuous scroll, and {@link com.pdftron.pdf.Stamper#stampImage} can also silently
            // short-circuit when the parent tool's native context has not yet released its write
            // barrier (most common on {@link com.pdftron.pdf.tools.AdvancedShapeCreate#commit}, which
            // drives Bauhub polygon creation). Retry once after a further UI tick so the stamp
            // lands even when the first pass no-ops.
            ctrl.post(
                    () -> runUnderDocWriteLock(ctrl, () -> {
                        try {
                            if (!shapeAnnot.isValid() || alreadyHasPin(shapeAnnot)) {
                                return;
                            }
                            tryPlacePinForShape(ctrl, doc, shapeAnnot, tool);
                        } catch (Exception e) {
                            AnalyticsHandlerAdapter.getInstance().sendException(e);
                        }
                    }));
        };
        ctrl.post(placePin);
    }

    /**
     * {@link com.pdftron.pdf.Stamper#stampImage} writes into the PDFDoc and must hold an exclusive
     * write lock. {@link PDFViewCtrl#post} queues onto the UI thread without any lock, so both the
     * scheduled and fallback passes of {@link #ensurePinForNewShape} must acquire one themselves —
     * otherwise {@code stampImage} silently drops the operation and the decorative pin never
     * appears (repro: Bauhub polygon area on Android; the square/rect tool was incidentally safe
     * because its pin placement happened while the tool still held the lock internally).
     */
    private static void runUnderDocWriteLock(@NonNull PDFViewCtrl ctrl, @NonNull Runnable body) {
        boolean locked = false;
        try {
            ctrl.docLock(true);
            locked = true;
            body.run();
        } catch (Exception e) {
            AnalyticsHandlerAdapter.getInstance().sendException(e);
        } finally {
            if (locked) {
                try {
                    ctrl.docUnlock();
                } catch (Exception ignored) {
                }
            }
        }
    }

    private static void tryPlacePinForShape(
            @NonNull PDFViewCtrl ctrl,
            @NonNull PDFDoc doc,
            @NonNull Annot shapeAnnot,
            @Nullable Tool tool)
            throws PDFNetException {
        int pageNum = resolvePageNumberForShapeAnnot(ctrl, doc, shapeAnnot, tool);
        if (pageNum > 0) {
            applyPinForShapeAnnot(ctrl, doc, pageNum, shapeAnnot, tool);
        }
    }

    /**
     * Resolves 1-based page number for stamping. {@link Annot#getPage()} is authoritative; scanning
     * {@link Page#getAnnot(int)} can lag right after create; {@link PDFViewCtrl#getCurrentPage()} is
     * often wrong in multi-page continuous mode (viewer "active" page vs page where the user drew).
     * When a {@link Tool} is {@link BauhubAreaMarkupTool} / {@link BauhubPolygonMarkupTool}, use
     * {@link BauhubAreaMarkupTool#getBauhubShapeCreationPageNum()} as a hint before falling back to current page.
     */
    public static int resolvePageNumberForShapeAnnot(
            @NonNull PDFViewCtrl ctrl, @NonNull PDFDoc doc, @NonNull Annot shapeAnnot)
            throws PDFNetException {
        return resolvePageNumberForShapeAnnot(ctrl, doc, shapeAnnot, null);
    }

    public static int resolvePageNumberForShapeAnnot(
            @NonNull PDFViewCtrl ctrl,
            @NonNull PDFDoc doc,
            @NonNull Annot shapeAnnot,
            @Nullable Tool tool)
            throws PDFNetException {
        try {
            Page pg = shapeAnnot.getPage();
            if (pg != null && pg.isValid()) {
                int idx = pg.getIndex();
                if (idx > 0) {
                    return idx;
                }
            }
        } catch (Exception ignored) {
        }
        int onPage = findPageNumberForAnnot(doc, shapeAnnot);
        if (onPage > 0) {
            return onPage;
        }
        int fromTool = bauhubShapeCreationPageFromTool(tool);
        if (fromTool > 0) {
            return fromTool;
        }
        int current = ctrl.getCurrentPage();
        if (current > 0) {
            return current;
        }
        return -1;
    }

    private static int bauhubShapeCreationPageFromTool(@Nullable Tool tool) {
        if (tool instanceof BauhubAreaMarkupTool) {
            int p = ((BauhubAreaMarkupTool) tool).getBauhubShapeCreationPageNum();
            return p >= 1 ? p : -1;
        }
        if (tool instanceof BauhubPolygonMarkupTool) {
            int p = ((BauhubPolygonMarkupTool) tool).getBauhubShapeCreationPageNum();
            return p >= 1 ? p : -1;
        }
        return -1;
    }

    private static int findPageNumberForAnnot(@NonNull PDFDoc doc, @NonNull Annot target)
            throws PDFNetException {
        Obj targetObj = target.getSDFObj();
        if (targetObj == null) {
            return -1;
        }
        long targetNum = targetObj.getObjNum();
        int targetGen = targetObj.getGenNum();
        int pageCount = doc.getPageCount();
        for (int p = 1; p <= pageCount; p++) {
            Page page = doc.getPage(p);
            int n = page.getNumAnnots();
            for (int i = 0; i < n; i++) {
                Annot a = page.getAnnot(i);
                if (a == null || !a.isValid()) {
                    continue;
                }
                Obj o = a.getSDFObj();
                if (o != null && o.getObjNum() == targetNum && o.getGenNum() == targetGen) {
                    return p;
                }
            }
        }
        return -1;
    }

    private static boolean matchesBauhubShape(Annot a) throws PDFNetException {
        int t = a.getType();
        if (t != Annot.e_Square && t != Annot.e_Polygon) {
            return false;
        }
        if (!a.isMarkup()) {
            return false;
        }
        Markup m = new Markup(a);
        String subj = m.getSubject();
        return "Comment".equals(subj) || "Attachment".equals(subj) || "Task".equals(subj);
    }

    private static boolean alreadyHasPin(Annot a) throws PDFNetException {
        String v = a.getCustomData(CUSTOM_DATA_KEY);
        return v != null && !v.isEmpty();
    }

    /**
     * True if this page already has a Bauhub decorative area-pin stamp linked to the shape's unique id.
     * Prefer this over {@link #alreadyHasPin} when deciding whether the canvas actually shows a pin.
     */
    private static boolean pageHasLinkedDecorativePinForShape(@NonNull Page page, @Nullable String shapeUid)
            throws PDFNetException {
        if (shapeUid == null || shapeUid.isEmpty()) {
            return false;
        }
        int n = page.getNumAnnots();
        for (int i = 0; i < n; i++) {
            Annot a = page.getAnnot(i);
            if (a == null || !a.isValid() || a.getType() != Annot.e_Stamp) {
                continue;
            }
            String dec = null;
            try {
                dec = a.getCustomData(DECORATIVE_STAMP_CUSTOM_KEY);
            } catch (Exception ignored) {
            }
            if (dec == null || dec.isEmpty()) {
                continue;
            }
            String puid = null;
            try {
                puid = a.getCustomData(PARENT_SHAPE_UID_KEY);
            } catch (Exception ignored) {
            }
            if (shapeUid.equals(puid)) {
                return true;
            }
        }
        return false;
    }

    private static boolean hasPinStampNearShapeCorner(Page page, Rect bbox, String shapeSubject) throws PDFNetException {
        double minX = Math.min(bbox.getX1(), bbox.getX2());
        double maxY = Math.max(bbox.getY1(), bbox.getY2());
        double targetX = minX + PAD + 12.0;
        double targetY = maxY - PAD - 12.0;
        int n = page.getNumAnnots();
        for (int i = 0; i < n; i++) {
            Annot a = page.getAnnot(i);
            if (a == null || !a.isValid() || a.getType() != Annot.e_Stamp) {
                continue;
            }
            String dec = null;
            try {
                dec = a.getCustomData(DECORATIVE_STAMP_CUSTOM_KEY);
            } catch (Exception ignored) {
            }
            if (dec != null && !dec.isEmpty()) {
                Rect r = a.getRect();
                if (near(targetX, targetY, r)) {
                    return true;
                }
            }
            // Do not treat arbitrary same-subject stamps as area pins — point pins share Comment/Attachment subject.
        }
        return false;
    }

    private static boolean near(double tx, double ty, Rect r) throws PDFNetException {
        double cx = (r.getX1() + r.getX2()) / 2.0;
        double cy = (r.getY1() + r.getY2()) / 2.0;
        return Math.hypot(cx - tx, cy - ty) < 40.0;
    }

    private static void applyPinForShapeAnnot(
            @NonNull PDFViewCtrl pdfViewCtrl,
            @NonNull PDFDoc doc,
            int pageNum,
            @NonNull Annot shapeAnnot,
            @Nullable Tool toolForAuthor) {
        try {
            if (!shapeAnnot.isValid() || !shapeAnnot.isMarkup()) {
                return;
            }
            Markup shapeMarkup = new Markup(shapeAnnot);
            String subj = shapeMarkup.getSubject();

            Rect bbox = shapeAnnot.getRect();
            Page pageForDedup = doc.getPage(pageNum);
            Obj uidObjEarly = shapeAnnot.getUniqueID();
            if (uidObjEarly != null) {
                String shapeUid = uidObjEarly.getAsPDFText();
                if (shapeUid != null
                        && !shapeUid.isEmpty()
                        && pageHasLinkedDecorativePinForShape(pageForDedup, shapeUid)) {
                    shapeAnnot.setCustomData(CUSTOM_DATA_KEY, "1");
                    pdfViewCtrl.update(shapeAnnot, pageNum);
                    return;
                }
            }
            if (hasPinStampNearShapeCorner(pageForDedup, bbox, subj)) {
                shapeAnnot.setCustomData(CUSTOM_DATA_KEY, "1");
                return;
            }

            double minX = Math.min(bbox.getX1(), bbox.getX2());
            double maxY = Math.max(bbox.getY1(), bbox.getY2());

            Context ctx = pdfViewCtrl.getContext();
            int rawId;
            String imgName;

            if ("Attachment".equalsIgnoreCase(subj)) {
                rawId = R.raw.bauhub_attachment_pin;
                imgName = "bauhub_attachment_pin";
            } else if ("Task".equalsIgnoreCase(subj)) {
                rawId = BauhubWebPinAssets.taskStampRawId(ctx);
                imgName = BauhubWebPinAssets.taskStampBaseName(ctx);
            } else {
                rawId = R.raw.bauhub_comment_pin;
                imgName = "bauhub_comment_pin";
            }

            Annot stamp =
                    BauhubStampPlacement.placeFromRawAtAreaTopLeft(
                            pdfViewCtrl,
                            pageNum,
                            rawId,
                            imgName,
                            minX,
                            maxY,
                            PAD,
                            toolForAuthor,
                            subj,
                            true);
            if (stamp != null && stamp.isValid()) {
                try {
                    Obj uidObj = shapeAnnot.getUniqueID();
                    if (uidObj != null) {
                        String uid = uidObj.getAsPDFText();
                        if (uid != null && !uid.isEmpty()) {
                            stamp.setCustomData(PARENT_SHAPE_UID_KEY, uid);
                        }
                    }
                } catch (Exception ignored) {
                }
            }

            shapeAnnot.setCustomData(CUSTOM_DATA_KEY, "1");
            pdfViewCtrl.update(shapeAnnot, pageNum);
            // PDFViewCtrl may composite the last-updated annot on top; updating only the shape leaves the
            // pin under the translucent fill until reload. Refresh the decorative stamp after the shape.
            if (stamp != null && stamp.isValid()) {
                pdfViewCtrl.update(stamp, pageNum);
            }
            scheduleEnsureDecorativeAreaPinStampLastOnPage(
                    pdfViewCtrl, doc, pageNum, shapeAnnot, toolForAuthor);
            BauhubDecorativeAreaPinZoomSync.requestSyncAfterStampPlaced(pdfViewCtrl);
        } catch (Exception e) {
            AnalyticsHandlerAdapter.getInstance().sendException(e);
        }
    }

    /**
     * Android draws annotations in page {@code Annots} array order (later entries on top). Deferred
     * {@link BauhubShapeMarkupStyle#apply} can leave the square/polygon after the decorative stamp in
     * that array, so the fill covers the pin until reopen. Move the matching decorative stamp to the
     * end of the array so it paints on top — same as after a full reload.
     * <p>
     * Posted with {@link PDFViewCtrl#post} and uses {@link PDFViewCtrl#docLock(boolean)} so we do not
     * nest a lock while {@code apply} runs inside tool/deferred handlers that may already hold the doc.
     */
    public static void scheduleEnsureDecorativeAreaPinStampLastOnPage(
            @NonNull PDFViewCtrl ctrl,
            @Nullable PDFDoc doc,
            int pageNum,
            @NonNull Annot shapeAnnot,
            @Nullable Tool toolForPageHint) {
        if (doc == null) {
            return;
        }
        ctrl.post(
                () -> {
                    boolean unlock = false;
                    try {
                        ctrl.docLock(true);
                        unlock = true;
                        ensureDecorativeAreaPinStampLastOnPageImpl(
                                ctrl, doc, pageNum, shapeAnnot, toolForPageHint);
                    } catch (Exception e) {
                        AnalyticsHandlerAdapter.getInstance().sendException(e);
                    } finally {
                        if (unlock) {
                            try {
                                ctrl.docUnlock();
                            } catch (Exception ignored) {
                            }
                        }
                    }
                });
    }

    private static void ensureDecorativeAreaPinStampLastOnPageImpl(
            @NonNull PDFViewCtrl ctrl,
            @NonNull PDFDoc doc,
            int pageNum,
            @NonNull Annot shapeAnnot,
            @Nullable Tool toolForPageHint) {
        try {
            if (!shapeAnnot.isValid()) {
                return;
            }
            int p = pageNum;
            if (p < 1) {
                p = resolvePageNumberForShapeAnnot(ctrl, doc, shapeAnnot, toolForPageHint);
            }
            if (p < 1) {
                try {
                    p = ctrl.getCurrentPage();
                } catch (Exception ignored) {
                }
            }
            if (p < 1) {
                return;
            }
            Obj uidObj = shapeAnnot.getUniqueID();
            if (uidObj == null) {
                return;
            }
            String uid = uidObj.getAsPDFText();
            if (uid == null || uid.isEmpty()) {
                return;
            }
            Page page = doc.getPage(p);
            int n = page.getNumAnnots();
            int stampIdx = -1;
            for (int i = 0; i < n; i++) {
                Annot a = page.getAnnot(i);
                if (a == null || !a.isValid() || a.getType() != Annot.e_Stamp) {
                    continue;
                }
                String dec = null;
                try {
                    dec = a.getCustomData(DECORATIVE_STAMP_CUSTOM_KEY);
                } catch (Exception ignored) {
                }
                if (dec == null || dec.isEmpty()) {
                    continue;
                }
                String puid = null;
                try {
                    puid = a.getCustomData(PARENT_SHAPE_UID_KEY);
                } catch (Exception ignored) {
                }
                if (uid.equals(puid)) {
                    stampIdx = i;
                    break;
                }
            }
            if (stampIdx < 0) {
                return;
            }
            if (stampIdx == n - 1) {
                Annot last = page.getAnnot(stampIdx);
                if (last != null && last.isValid()) {
                    ctrl.update(last, p);
                }
                return;
            }
            // Only reorder if the stamp paints UNDER its OWN parent shape — i.e. the shape is at a
            // HIGHER index than the stamp. If the stamp is merely "not last" because some other
            // annotation (another area's stamp/shape, a freehand stroke, etc.) was appended after
            // it, the stamp is still above its own parent shape, which is the only visual invariant
            // we care about. Avoiding the {@code page.annotRemove} call in that benign case is
            // critical: even though we recreate a fresh stamp afterwards, the {@code annotRemove}
            // alone leaves a stale pointer in PDFTron's native hit-test cache — subsequent taps
            // resolve to an invalid {@link Annot} wrapper and {@code Annot.isMarkup} throws
            // "Operation on invalid object", crashing {@code AdvancedShapeCreate.canSelectTool},
            // {@code Pan.selectAnnot}, and {@code AnnotEdit.onSingleTapConfirmed}.
            long shapeObjNum = -1L;
            try {
                Obj shapeSdf = shapeAnnot.getSDFObj();
                if (shapeSdf != null && !shapeSdf.isNull()) {
                    shapeObjNum = shapeSdf.getObjNum();
                }
            } catch (Exception ignored) {
            }
            if (shapeObjNum > 0) {
                int shapeIdx = -1;
                for (int i = 0; i < n; i++) {
                    Annot a = page.getAnnot(i);
                    if (a == null || !a.isValid()) {
                        continue;
                    }
                    try {
                        Obj sdf = a.getSDFObj();
                        if (sdf == null || sdf.isNull()) {
                            continue;
                        }
                        if (sdf.getObjNum() == shapeObjNum) {
                            shapeIdx = i;
                            break;
                        }
                    } catch (Exception ignored) {
                    }
                }
                if (shapeIdx >= 0 && shapeIdx < stampIdx) {
                    // Stamp is already above its own parent shape in paint order. Nothing to do.
                    Annot cur = page.getAnnot(stampIdx);
                    if (cur != null && cur.isValid()) {
                        ctrl.update(cur, p);
                    }
                    return;
                }
            }
            // Reorder genuinely required (shape is above stamp in paint order → pin is hidden).
            // Do NOT reuse the stamp's SDF obj via {@code new Annot(sdfObj) + page.annotPushBack}:
            // PDFTron's native annotation-at-point cache (used by {@code PDFViewCtrl.getAnnotationAt}
            // → {@code ToolManager.getAnnotationAt} → {@code AnnotUtils.hasPermission} →
            // {@code Annot.isMarkup}) retains a pointer tied to the original {@code AnnotRemove} and
            // then resolves taps to an invalid {@code Annot} wrapper. {@code hasPermission} catches
            // the resulting "Operation on invalid object" but defaults to {@code true}, breaking
            // every {@code canSelectTool}/{@code selectAnnot} path ({@code Pan},
            // {@code AnnotEdit}, {@code AdvancedShapeCreate}). Instead, remove the stamp outright
            // and recreate a fresh one from the shape — naturally appended at the end of the
            // {@code Annots} array, so it paints on top without any in-place reorder.
            Annot stampAtIdx = page.getAnnot(stampIdx);
            ToolManager tm = null;
            try {
                Object raw = ctrl.getToolManager();
                if (raw instanceof ToolManager) {
                    tm = (ToolManager) raw;
                }
            } catch (Exception ignored) {
            }
            Map<Annot, Integer> removedMap = new HashMap<>();
            removedMap.put(stampAtIdx, p);
            if (tm != null) {
                try {
                    tm.raiseAnnotationsPreRemoveEvent(removedMap);
                } catch (Exception ignored) {
                }
            }
            page.annotRemove(stampIdx);
            if (tm != null) {
                try {
                    tm.raiseAnnotationsRemovedEvent(removedMap);
                } catch (Exception ignored) {
                }
            }
            // Clear the per-shape {@code CUSTOM_DATA_KEY} so {@link #applyPinForShapeAnnot}'s dedup
            // check (and {@link #alreadyHasPin}) lets it drop a brand-new stamp. Without this the
            // helper short-circuits and we end up with a shape that has no pin.
            try {
                shapeAnnot.setCustomData(CUSTOM_DATA_KEY, "");
            } catch (Exception ignored) {
            }
            applyPinForShapeAnnot(ctrl, doc, p, shapeAnnot, toolForPageHint);
        } catch (Exception e) {
            AnalyticsHandlerAdapter.getInstance().sendException(e);
        }
    }

    /**
     * After {@link PDFViewCtrl#update(Annot, int)} on a Bauhub area shape, call this so the decorative
     * pin stamp is updated last and paints above the translucent area (matches order after reopen).
     */
    public static void refreshDecorativePinViewAfterShapeUpdate(
            @NonNull PDFViewCtrl ctrl, @Nullable PDFDoc doc, int pageNum, @NonNull Annot shapeAnnot) {
        if (doc == null || pageNum < 1) {
            return;
        }
        try {
            if (!shapeAnnot.isValid()) {
                return;
            }
            Obj uidObj = shapeAnnot.getUniqueID();
            if (uidObj == null) {
                return;
            }
            String uid = uidObj.getAsPDFText();
            if (uid == null || uid.isEmpty()) {
                return;
            }
            Page page = doc.getPage(pageNum);
            int n = page.getNumAnnots();
            for (int i = 0; i < n; i++) {
                Annot a = page.getAnnot(i);
                if (a == null || !a.isValid() || a.getType() != Annot.e_Stamp) {
                    continue;
                }
                String dec = null;
                try {
                    dec = a.getCustomData(DECORATIVE_STAMP_CUSTOM_KEY);
                } catch (Exception ignored) {
                }
                if (dec == null || dec.isEmpty()) {
                    continue;
                }
                String puid = null;
                try {
                    puid = a.getCustomData(PARENT_SHAPE_UID_KEY);
                } catch (Exception ignored) {
                }
                if (uid.equals(puid)) {
                    ctrl.update(a, pageNum);
                    return;
                }
            }
        } catch (Exception e) {
            AnalyticsHandlerAdapter.getInstance().sendException(e);
        }
    }

    /**
     * Moves the decorative pin stamp linked to {@code shapeAnnot} so it tracks the shape's top-left
     * corner after a move/resize. The pin is an independent stamp anchored at placement time; without
     * this it stays at the corner where the shape was first drawn (the "pin left behind until reopen"
     * ghost). Only the anchor moves — the pin keeps its current size (constant on-screen via the
     * {@code e_no_zoom} flag).
     *
     * <p>Caller must already hold the doc write-lock. Updates both the stamp and the shape so the
     * canvas repaints the pin at its new location immediately.
     */
    public static void repositionDecorativePinForParentShape(
            @NonNull PDFViewCtrl ctrl, @NonNull PDFDoc doc, int pageNum, @NonNull Annot shapeAnnot) {
        try {
            String parentUid = bauhubAreaParentUidFromShapeAnnot(shapeAnnot);
            if (parentUid == null || parentUid.isEmpty()) {
                return;
            }
            if (pageNum < 1) {
                pageNum = resolvePageNumberForShapeAnnot(ctrl, doc, shapeAnnot);
            }
            if (pageNum < 1) {
                return;
            }
            Rect bbox = shapeAnnot.getRect();
            double newAx = Math.min(bbox.getX1(), bbox.getX2()) + PAD;
            double newAy = Math.max(bbox.getY1(), bbox.getY2()) - PAD;
            Page page = doc.getPage(pageNum);
            if (page == null) {
                return;
            }
            int n = page.getNumAnnots();
            for (int i = 0; i < n; i++) {
                Annot a = page.getAnnot(i);
                if (a == null || !a.isValid() || a.getType() != Annot.e_Stamp) {
                    continue;
                }
                String dec = null;
                try {
                    dec = a.getCustomData(DECORATIVE_STAMP_CUSTOM_KEY);
                } catch (Exception ignored) {
                }
                if (dec == null || dec.isEmpty()) {
                    continue;
                }
                String puid = null;
                try {
                    puid = a.getCustomData(PARENT_SHAPE_UID_KEY);
                } catch (Exception ignored) {
                }
                if (!parentUid.equals(puid)) {
                    continue;
                }
                Rect r = a.getRect();
                double spanW = Math.abs(r.getX2() - r.getX1());
                double spanH = Math.abs(r.getY2() - r.getY1());
                if (spanW < 0.5) {
                    spanW = 0.5;
                }
                if (spanH < 0.5) {
                    spanH = 0.5;
                }
                Rect newRect = new Rect(newAx, newAy - spanH, newAx + spanW, newAy);
                a.setRect(newRect);
                try {
                    a.setCustomData(BauhubDecorativeAreaPinZoomSync.PIN_PAGE_AX_KEY, Double.toString(newAx));
                    a.setCustomData(BauhubDecorativeAreaPinZoomSync.PIN_PAGE_AY_KEY, Double.toString(newAy));
                } catch (Exception ignored) {
                }
                ctrl.update(a, pageNum);
                break;
            }
            ctrl.update(shapeAnnot, pageNum);
        } catch (Exception e) {
            AnalyticsHandlerAdapter.getInstance().sendException(e);
        }
    }
}
