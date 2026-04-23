package com.pdftron.pdftronflutter.bauhub;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.annotation.RawRes;

import com.pdftron.common.PDFNetException;
import com.pdftron.filters.Filter;
import com.pdftron.filters.SecondaryFileFilter;
import com.pdftron.pdf.Image;
import com.pdftron.pdf.utils.Utils;
import com.pdftron.sdf.SDFDoc;

import java.io.FileNotFoundException;

/**
 * Embeds Bauhub pin PNGs into the PDF. Prefer {@link #loadPinImageWithFallback}: decoding via
 * {@link android.graphics.Bitmap} avoids broken/red stamp appearance seen with
 * {@link SecondaryFileFilter} + PNG {@link Image#create} on some devices.
 */
public final class BauhubPinPdfImage {

    /**
     * Task web pins ship as ~768px rasters; comment/attachment pins were 144px. Stamper + PDF image
     * sizing on Android then diverges from task pins and can show a wrong placeholder appearance.
     */
    private static final int PIN_RASTER_TARGET_MAX_SIDE = 768;
    private static final int PIN_RASTER_UPSCALE_IF_MAX_SIDE_BELOW = 400;

    private BauhubPinPdfImage() {
    }

    /**
     * Upscale small Bauhub pin PNGs so embedded stamp dimensions match high-res task pins.
     */
    @NonNull
    private static Bitmap decodePinBitmapUpscaledIfNeeded(@NonNull Context context, @RawRes int resId) {
        BitmapFactory.Options opts = new BitmapFactory.Options();
        opts.inScaled = false;
        opts.inPreferredConfig = Bitmap.Config.ARGB_8888;
        Bitmap bmp = BitmapFactory.decodeResource(context.getResources(), resId, opts);
        if (bmp == null) {
            throw new IllegalStateException("decodeResource null for resId=" + resId);
        }
        int w = bmp.getWidth();
        int h = bmp.getHeight();
        int maxSide = Math.max(w, h);
        if (maxSide >= PIN_RASTER_UPSCALE_IF_MAX_SIDE_BELOW) {
            return bmp;
        }
        float scale = (float) PIN_RASTER_TARGET_MAX_SIDE / (float) maxSide;
        int nw = Math.max(1, Math.round(w * scale));
        int nh = Math.max(1, Math.round(h * scale));
        Bitmap scaled = Bitmap.createScaledBitmap(bmp, nw, nh, true);
        if (scaled != bmp) {
            bmp.recycle();
        }
        return scaled;
    }

    @NonNull
    public static Image createFromRawResource(
            @NonNull SDFDoc sdfDoc, @NonNull Context context, @RawRes int resId)
            throws PDFNetException, InterruptedException {
        Bitmap bmp = decodePinBitmapUpscaledIfNeeded(context, resId);
        try {
            return Image.create(sdfDoc, bmp);
        } finally {
            bmp.recycle();
        }
    }

    @NonNull
    public static Image loadPinImageWithFallback(
            @NonNull SDFDoc sdfDoc,
            @NonNull Context context,
            @RawRes int rawResId,
            @NonNull Uri copiedFileUri)
            throws PDFNetException, InterruptedException {
        try {
            return createFromRawResource(sdfDoc, context, rawResId);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } catch (PDFNetException | RuntimeException ignored) {
        }
        SecondaryFileFilter filter;
        try {
            filter = new SecondaryFileFilter(context, copiedFileUri);
        } catch (FileNotFoundException e) {
            throw new IllegalStateException("Bauhub pin PNG copy not found: " + copiedFileUri, e);
        }
        try {
            return Image.create(sdfDoc, filter);
        } finally {
            Utils.closeQuietly(filter);
        }
    }

    @NonNull
    public static Image createFromPngFilter(@NonNull SDFDoc sdfDoc, @NonNull Filter filter)
            throws PDFNetException {
        return Image.create(sdfDoc, filter);
    }
}
