package com.pdftron.pdftronflutter.bauhub;

import androidx.annotation.NonNull;

import com.pdftron.pdf.PDFViewCtrl;

/**
 * Decorative area-pin stamps carry the real {@link com.pdftron.pdf.Annot#e_no_zoom} flag (set in
 * {@link BauhubWebStyleXfdf#applyToStamp}), so PDFTron keeps them at a constant on-screen size
 * natively — exactly like the web viewer (XFDF {@code flags="print,nozoom,norotate"}).
 *
 * <p>This class previously <b>faked</b> the no-zoom behaviour by resizing each pin's page-space
 * rect on every zoom change. With the {@code e_no_zoom} flag now in place that manual resize is not
 * only redundant, it actively fights the flag: zooming in shrank the page-rect, and because the
 * flag ties the on-screen size to the rect, the pin visibly shrank. The sync is therefore a no-op —
 * the {@code PIN_PAGE_AX/AY} keys are still used as the pin's fixed corner anchor by
 * {@link BauhubAreaPinDecoration}.
 */
public final class BauhubDecorativeAreaPinZoomSync {

    /** PDF rect corner that stays fixed (left = {@code min(x)}, top = {@code max(y)}); anchor only — no longer zoom-resized. */
    public static final String PIN_PAGE_AX_KEY = "BauhubPinPageAx";
    public static final String PIN_PAGE_AY_KEY = "BauhubPinPageAy";

    private BauhubDecorativeAreaPinZoomSync() {
    }

    /** No-op: constant on-screen pin size is handled natively by the {@code e_no_zoom} flag. */
    public static void requestSync(@NonNull PDFViewCtrl pdfViewCtrl) {
    }

    /** No-op: constant on-screen pin size is handled natively by the {@code e_no_zoom} flag. */
    public static void requestSyncAfterStampPlaced(@NonNull PDFViewCtrl pdfViewCtrl) {
    }
}
