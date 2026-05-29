package com.pdftron.pdftronflutter.bauhub;

import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.pdftron.common.Matrix2D;
import com.pdftron.common.PDFNetException;
import com.pdftron.pdf.Annot;
import com.pdftron.pdf.Image;
import com.pdftron.pdf.PDFDoc;
import com.pdftron.pdf.PDFViewCtrl;
import com.pdftron.pdf.Page;
import com.pdftron.pdf.PageSet;
import com.pdftron.pdf.Point;
import com.pdftron.pdf.Rect;
import com.pdftron.pdf.Stamper;
import com.pdftron.pdf.annots.Markup;
import com.pdftron.pdf.tools.Tool;
import com.pdftron.pdf.tools.ToolManager;
import com.pdftron.pdf.utils.Utils;
import com.pdftron.sdf.Obj;

import java.io.File;

/**
 * Places an image stamp using the same geometry as {@link BauhubPinStampTool} (centered anchor in
 * page coordinates, then default matrix + half-size offset + crop clamp).
 */
public final class BauhubStampPlacement {

    private BauhubStampPlacement() {
    }

    /** [width, height] in page units — same scaling as {@link BauhubPinStampTool}. */
    @NonNull
    public static double[] computeScaledStampSize(
            @NonNull PDFViewCtrl pdfViewCtrl,
            @NonNull Page page,
            @NonNull Image img) throws PDFNetException {
        Rect pageViewBox = page.getBox(pdfViewCtrl.getPageBox());
        int pageRotation = page.getRotation();
        int viewRotation = pdfViewCtrl.getPageRotation();

        double stampWidth = img.getImageWidth();
        double stampHeight = img.getImageHeight();

        double pageWidth = pageViewBox.getWidth();
        double pageHeight = pageViewBox.getHeight();
        if (pageRotation == 1 || pageRotation == 3) {
            double tmp = pageWidth;
            pageWidth = pageHeight;
            pageHeight = tmp;
        }

        double maxImageWidthPage = 25.0;
        double maxImageHeightPage = 25.0;
        if (pageWidth < maxImageWidthPage) {
            maxImageWidthPage = pageWidth;
        }
        if (pageHeight < maxImageHeightPage) {
            maxImageHeightPage = pageHeight;
        }

        if (viewRotation == 1 || viewRotation == 3) {
            double tmp = maxImageWidthPage;
            maxImageWidthPage = maxImageHeightPage;
            maxImageHeightPage = tmp;
        }

        double scaleFactor = Math.min(maxImageWidthPage / stampWidth, maxImageHeightPage / stampHeight);
        stampWidth *= scaleFactor;
        stampHeight *= scaleFactor;

        if (viewRotation == 1 || viewRotation == 3) {
            double temp = stampWidth;
            stampWidth = stampHeight;
            stampHeight = temp;
        }
        return new double[]{stampWidth, stampHeight};
    }

    /**
     * Icon centered at visual top-left of the shape (padding + half size), matching web
     * {@code translate(corner + iconSize/2)}.
     */
    @Nullable
    public static Annot placeFromRawAtAreaTopLeft(
            @NonNull PDFViewCtrl pdfViewCtrl,
            int pageNum,
            int rawId,
            @NonNull String imageBaseName,
            double minX,
            double maxY,
            double pad,
            @Nullable Tool toolForAuthor,
            @Nullable String markupSubject,
            boolean decorative) throws Exception {
        PDFDoc doc = pdfViewCtrl.getDoc();
        File resource = Utils.copyResourceToLocal(pdfViewCtrl.getContext(), rawId, imageBaseName, "png");
        Image img = BauhubPinPdfImage.loadPinImageWithFallback(
                doc.getSDFDoc(), pdfViewCtrl.getContext(), rawId, Uri.fromFile(resource));
        Page page = doc.getPage(pageNum);
        double[] wh = computeScaledStampSize(pdfViewCtrl, page, img);
        double anchorX = minX + pad + wh[0] / 2.0;
        double anchorY = maxY - pad - wh[1] / 2.0;
        return placeImageStampLikePointPin(
                pdfViewCtrl, doc, pageNum, img,
                anchorX, anchorY, toolForAuthor, markupSubject, decorative);
    }

    /**
     * @param anchorPageX center X of the stamp in page user space (same space as
     *                    {@link PDFViewCtrl#convScreenPtToPagePt(double, double, int)} output)
     * @param anchorPageY center Y of the stamp in page user space
     */
    @Nullable
    public static Annot placeImageStampLikePointPin(
            @NonNull PDFViewCtrl pdfViewCtrl,
            @NonNull PDFDoc doc,
            int pageNum,
            @NonNull Image img,
            double anchorPageX,
            double anchorPageY,
            @Nullable Tool toolForAuthor,
            @Nullable String markupSubject,
            boolean decorative) throws Exception {
        if (pageNum <= 0) {
            return null;
        }
        Page page = doc.getPage(pageNum);
        int viewRotation = pdfViewCtrl.getPageRotation();
        Rect pageViewBox = page.getBox(pdfViewCtrl.getPageBox());
        Rect pageCropBox = page.getCropBox();
        int pageRotation = page.getRotation();

        double[] wh = computeScaledStampSize(pdfViewCtrl, page, img);
        double stampWidth = wh[0];
        double stampHeight = wh[1];

        double pageWidth = pageViewBox.getWidth();
        double pageHeight = pageViewBox.getHeight();
        if (pageRotation == 1 || pageRotation == 3) {
            double tmp = pageWidth;
            pageWidth = pageHeight;
            pageHeight = tmp;
        }

        Matrix2D mtx = page.getDefaultMatrix();
        Point pageTargetPoint = mtx.multPoint(anchorPageX, anchorPageY);
        Stamper stamper = new Stamper(2, stampWidth, stampHeight);
        stamper.setAlignment(-1, -1);
        pageTargetPoint.x -= stampWidth / 2.0;
        pageTargetPoint.y -= stampHeight / 2.0;

        double leftEdge = pageViewBox.getX1() - pageCropBox.getX1();
        double bottomEdge = pageViewBox.getY1() - pageCropBox.getY1();
        if (pageTargetPoint.x > leftEdge + pageWidth - stampWidth) {
            pageTargetPoint.x = leftEdge + pageWidth - stampWidth;
        }
        if (pageTargetPoint.x < leftEdge) {
            pageTargetPoint.x = leftEdge;
        }
        if (pageTargetPoint.y > bottomEdge + pageHeight - stampHeight) {
            pageTargetPoint.y = bottomEdge + pageHeight - stampHeight;
        }
        if (pageTargetPoint.y < bottomEdge) {
            pageTargetPoint.y = bottomEdge;
        }

        stamper.setAsAnnotation(true);
        stamper.setPosition(pageTargetPoint.x, pageTargetPoint.y);
        int stampRotation = (4 - viewRotation) % 4;
        stamper.setRotation(stampRotation * 90.0);
        stamper.stampImage(doc, img, new PageSet(pageNum));

        int numAnnots = page.getNumAnnots();
        Annot stampAnnot = page.getAnnot(numAnnots - 1);
        if (stampAnnot == null || !stampAnnot.isValid()) {
            return null;
        }
        Obj obj = stampAnnot.getSDFObj();
        obj.putNumber("pdftronImageStampRotation", 0.0);
        if (stampAnnot.isMarkup()) {
            Markup markup = new Markup(stampAnnot);
            if (toolForAuthor != null) {
                ToolManager tm = (ToolManager) pdfViewCtrl.getToolManager();
                if (tm != null) {
                    Tool.setAuthorForAnnot(tm, markup);
                }
            }
            if (markupSubject != null && !markupSubject.isEmpty()) {
                markup.setSubject(markupSubject);
            }
            try {
                markup.setContents("");
            } catch (Exception ignored) {
            }
            // Decorative PNG stamps: refreshAppearance regenerates a default vector stamp (red box)
            // and replaces the image placed by Stamper — skip for Bauhub area pins.
            if (!decorative) {
                try {
                    stampAnnot.refreshAppearance();
                } catch (Exception ignored) {
                }
            }
        }
        if (decorative) {
            try {
                stampAnnot.setCustomData("BauhubDecorativeAreaPin", "1");
            } catch (Exception ignored) {
            }
            try {
                Rect cr = stampAnnot.getRect();
                double left = Math.min(cr.getX1(), cr.getX2());
                double top = Math.max(cr.getY1(), cr.getY2());
                stampAnnot.setCustomData(BauhubDecorativeAreaPinZoomSync.PIN_PAGE_AX_KEY,
                        Double.toString(left));
                stampAnnot.setCustomData(BauhubDecorativeAreaPinZoomSync.PIN_PAGE_AY_KEY,
                        Double.toString(top));
            } catch (Exception ignored) {
            }
            try {
                stampAnnot.setFlag(Annot.e_locked, true);
            } catch (Exception ignored) {
            }
            // Let taps reach the parent square/polygon: the pin is visual-only. Without this, the
            // topmost stamp can win hit-testing near the corner and the shape never receives the tap
            // (more noticeable on polygons with small screen-space edges).
            try {
                stampAnnot.setFlag(Annot.e_read_only, true);
            } catch (Exception ignored) {
            }
        }
        // Match WebViewer XFDF: flags="print,nozoom,norotate" + local-timezone dates. Applies to
        // both decorative and non-decorative stamp use-cases (point pin / standalone image stamp).
        BauhubWebStyleXfdf.applyToStamp(stampAnnot);
        pdfViewCtrl.update(stampAnnot, pageNum);
        return stampAnnot;
    }

    /**
     * Loads a PNG from raw, encodes like the pin tools, and places it.
     */
    @Nullable
    public static Annot placeFromRawResource(
            @NonNull PDFViewCtrl pdfViewCtrl,
            int pageNum,
            int rawId,
            @NonNull String imageBaseName,
            double anchorPageX,
            double anchorPageY,
            @Nullable Tool toolForAuthor,
            @Nullable String markupSubject,
            boolean decorative) throws Exception {
        PDFDoc doc = pdfViewCtrl.getDoc();
        File resource = Utils.copyResourceToLocal(pdfViewCtrl.getContext(), rawId, imageBaseName, "png");
        Image img = BauhubPinPdfImage.loadPinImageWithFallback(
                doc.getSDFDoc(), pdfViewCtrl.getContext(), rawId, Uri.fromFile(resource));
        return placeImageStampLikePointPin(
                pdfViewCtrl, doc, pageNum, img,
                anchorPageX, anchorPageY, toolForAuthor, markupSubject, decorative);
    }
}
