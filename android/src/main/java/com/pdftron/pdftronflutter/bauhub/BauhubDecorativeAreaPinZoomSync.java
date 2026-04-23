package com.pdftron.pdftronflutter.bauhub;

import android.content.res.Resources;
import android.os.Handler;
import android.os.Looper;
import android.util.TypedValue;

import androidx.annotation.NonNull;

import com.pdftron.common.PDFNetException;
import com.pdftron.pdf.Annot;
import com.pdftron.pdf.PDFDoc;
import com.pdftron.pdf.PDFViewCtrl;
import com.pdftron.pdf.Page;
import com.pdftron.pdf.Rect;

/**
 * Keeps decorative area-pin stamps at a ~constant on-screen size (about 24dp) when zoom changes,
 * matching web {@code PdfTronTools.applyPinIconDraw}: fixed corner {@code (cornerX, cornerY)} plus
 * {@code iconSize} in page space (not centered growth).
 * <p>
 * Page span is clamped (same max as area-pin stamp placement, {@code ~25} pt) so the pin does not
 * balloon when zoomed far out.
 */
public final class BauhubDecorativeAreaPinZoomSync {

    /** PDF rect corner that stays fixed when resizing: left ({@code min(x)}) and top ({@code max(y)}). */
    public static final String PIN_PAGE_AX_KEY = "BauhubPinPageAx";
    public static final String PIN_PAGE_AY_KEY = "BauhubPinPageAy";

    private static final long DEBOUNCE_MS = 48;
    /** Let multi-page layout report correct {@link PDFViewCtrl#getScreenRectForAnnot} before resizing. */
    private static final long STAMP_PLACE_SETTLE_MS = 160;
    /** Same cap as decorative area-pin stamp max width/height in page points. */
    private static final double MAX_PAGE_SPAN = 25.0;
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static Runnable sPending;

    private BauhubDecorativeAreaPinZoomSync() {
    }

    public static void requestSync(@NonNull PDFViewCtrl pdfViewCtrl) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            MAIN.post(() -> requestSync(pdfViewCtrl));
            return;
        }
        if (sPending != null) {
            MAIN.removeCallbacks(sPending);
        }
        final PDFViewCtrl ctrl = pdfViewCtrl;
        sPending = () -> {
            sPending = null;
            syncNow(ctrl);
        };
        MAIN.postDelayed(sPending, DEBOUNCE_MS);
    }

    /**
     * After a new decorative stamp is placed, {@link PDFViewCtrl#getScreenRectForAnnot} can be wrong
     * for one frame on multi-page documents — delay before {@link #requestSync} so pin size/position
     * sync does not jump to the wrong place.
     */
    public static void requestSyncAfterStampPlaced(@NonNull PDFViewCtrl pdfViewCtrl) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            MAIN.post(() -> requestSyncAfterStampPlaced(pdfViewCtrl));
            return;
        }
        MAIN.postDelayed(() -> requestSync(pdfViewCtrl), STAMP_PLACE_SETTLE_MS);
    }

    private static void syncNow(@NonNull PDFViewCtrl pdfViewCtrl) {
        PDFDoc doc = pdfViewCtrl.getDoc();
        if (doc == null) {
            return;
        }
        Resources res = pdfViewCtrl.getContext().getResources();
        float px = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 24f, res.getDisplayMetrics());
        boolean unlock = false;
        try {
            pdfViewCtrl.docLock(true);
            unlock = true;
            int pageCount = doc.getPageCount();
            for (int p = 1; p <= pageCount; p++) {
                Page page = doc.getPage(p);
                int n = page.getNumAnnots();
                for (int i = 0; i < n; i++) {
                    Annot a = page.getAnnot(i);
                    if (a == null || !a.isValid() || a.getType() != Annot.e_Stamp) {
                        continue;
                    }
                    String dec = null;
                    try {
                        dec = a.getCustomData(BauhubAreaPinDecoration.DECORATIVE_STAMP_CUSTOM_KEY);
                    } catch (Exception ignored) {
                    }
                    if (dec == null || dec.isEmpty()) {
                        continue;
                    }
                    Rect screen = pdfViewCtrl.getScreenRectForAnnot(a, p);
                    if (screen == null) {
                        continue;
                    }
                    double sw = Math.abs(screen.getX2() - screen.getX1());
                    double sh = Math.abs(screen.getY2() - screen.getY1());
                    if (sw < 2.0 && sh < 2.0) {
                        continue;
                    }
                    double scx = (screen.getX1() + screen.getX2()) / 2.0;
                    double scy = (screen.getY1() + screen.getY2()) / 2.0;

                    double[] c = pdfViewCtrl.convScreenPtToPagePt(scx, scy, p);
                    double[] rx = pdfViewCtrl.convScreenPtToPagePt(scx + px, scy, p);
                    double[] ry = pdfViewCtrl.convScreenPtToPagePt(scx, scy + px, p);
                    double spanH = Math.hypot(rx[0] - c[0], rx[1] - c[1]);
                    double spanV = Math.hypot(ry[0] - c[0], ry[1] - c[1]);
                    double span = Math.max(spanH, spanV);
                    span = Math.min(Math.max(span, 0.25), MAX_PAGE_SPAN);

                    double ax;
                    double ay;
                    try {
                        String sx = a.getCustomData(PIN_PAGE_AX_KEY);
                        String sy = a.getCustomData(PIN_PAGE_AY_KEY);
                        if (sx != null && sy != null && !sx.isEmpty() && !sy.isEmpty()) {
                            ax = Double.parseDouble(sx);
                            ay = Double.parseDouble(sy);
                        } else {
                            Rect pr = a.getRect();
                            ax = Math.min(pr.getX1(), pr.getX2());
                            ay = Math.max(pr.getY1(), pr.getY2());
                            a.setCustomData(PIN_PAGE_AX_KEY, Double.toString(ax));
                            a.setCustomData(PIN_PAGE_AY_KEY, Double.toString(ay));
                        }
                    } catch (Exception e) {
                        Rect pr = a.getRect();
                        ax = Math.min(pr.getX1(), pr.getX2());
                        ay = Math.max(pr.getY1(), pr.getY2());
                    }

                    double left = ax;
                    double top = ay;
                    double right = left + span;
                    double bottom = top - span;
                    Rect pageRect = new Rect(left, bottom, right, top);
                    a.setRect(pageRect);
                    a.refreshAppearance();
                    pdfViewCtrl.update(a, p);
                }
            }
        } catch (PDFNetException ignored) {
        } finally {
            if (unlock) {
                pdfViewCtrl.docUnlock();
            }
        }
    }
}
