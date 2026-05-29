package com.pdftron.pdftronflutter.bauhub;

import androidx.annotation.NonNull;

import com.pdftron.pdf.Annot;
import com.pdftron.sdf.Obj;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

/**
 * Aligns Bauhub mobile XFDF output with the web (WebViewer) format:
 *
 * <ul>
 *     <li><b>Dates</b> ({@code M}, {@code CreationDate}) — written as PDF Date strings with a
 *         local timezone offset (e.g. {@code D:20260529101309+03'00'}) instead of UTC
 *         ({@code D:20260529065415Z}). PDFTron iOS/Android default to UTC; the WebViewer SDK
 *         writes local time with offset. Matching the web format means activities created on
 *         mobile carry the same wall-clock timestamps as web activities when read back.</li>
 *     <li><b>Stamp flags</b> — sets {@link Annot#e_print} + {@link Annot#e_no_zoom} +
 *         {@link Annot#e_no_rotate} on point pin and decorative area pin stamps. The web emits
 *         {@code flags="print,nozoom,norotate"} so pins stay fixed-size and upright at any
 *         zoom/rotation. Mobile previously emitted only {@code print} and faked the no-zoom
 *         behaviour via {@link BauhubDecorativeAreaPinZoomSync} (decorative pins only) — setting
 *         the actual flags lets PDFTron handle constant on-screen size natively for both pin
 *         types, no manual rect resize needed.</li>
 * </ul>
 *
 * <p>Square / polygon area markups keep their default flags ({@code print} only) — only stamps
 * carry {@code nozoom,norotate} on web — so only date alignment is applied there.
 */
public final class BauhubWebStyleXfdf {

    private BauhubWebStyleXfdf() {
    }

    /**
     * Stamps (point pin + decorative area pin): write web-style flags and a local-timezone PDF
     * date for both {@code CreationDate} and {@code M}.
     */
    public static void applyToStamp(@NonNull Annot annot) {
        applyWebStampFlags(annot);
        writeLocalCreationAndModDates(annot);
    }

    /**
     * Square / polygon area markups: only the date format needs to match the web. Flags stay at
     * the PDFTron default ({@code print}) — web emits the same for {@code square}/{@code polygon}.
     */
    public static void applyToShape(@NonNull Annot annot) {
        writeLocalCreationAndModDates(annot);
    }

    private static void applyWebStampFlags(@NonNull Annot annot) {
        try {
            if (!annot.isValid()) {
                return;
            }
            annot.setFlag(Annot.e_print, true);
            annot.setFlag(Annot.e_no_zoom, true);
            annot.setFlag(Annot.e_no_rotate, true);
        } catch (Exception ignored) {
        }
    }

    private static void writeLocalCreationAndModDates(@NonNull Annot annot) {
        try {
            if (!annot.isValid()) {
                return;
            }
            Obj sdf = annot.getSDFObj();
            if (sdf == null || sdf.isNull()) {
                return;
            }
            String pdfDate = buildLocalPdfDateString(new Date());
            sdf.putString("M", pdfDate);
            sdf.putString("CreationDate", pdfDate);
        } catch (Exception ignored) {
        }
    }

    /**
     * Builds a PDF Date string in the form {@code D:YYYYMMDDHHmmSS±HH'mm'} using the device's
     * current local timezone (matches WebViewer's serialization). UTC times come back as
     * {@code D:...+00'00'} — same offset notation, no special {@code Z} case (web does the same).
     */
    static String buildLocalPdfDateString(@NonNull Date d) {
        TimeZone tz = TimeZone.getDefault();
        int offsetMs = tz.getOffset(d.getTime());
        char sign = offsetMs >= 0 ? '+' : '-';
        int absOffsetMin = Math.abs(offsetMs) / 60000;
        int offHrs = absOffsetMin / 60;
        int offMin = absOffsetMin % 60;
        SimpleDateFormat fmt = new SimpleDateFormat("yyyyMMddHHmmss", Locale.US);
        fmt.setTimeZone(tz);
        return String.format(Locale.US, "D:%s%c%02d'%02d'", fmt.format(d), sign, offHrs, offMin);
    }
}
