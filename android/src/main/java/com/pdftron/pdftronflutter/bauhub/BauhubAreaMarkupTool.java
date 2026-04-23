package com.pdftron.pdftronflutter.bauhub;

import android.view.MotionEvent;

import androidx.annotation.NonNull;

import com.pdftron.common.PDFNetException;
import com.pdftron.pdf.Annot;
import com.pdftron.pdf.PDFDoc;
import com.pdftron.pdf.PDFViewCtrl;
import com.pdftron.pdf.Rect;
import com.pdftron.pdf.model.AnnotStyle;
import com.pdftron.pdf.tools.RectCreate;
import com.pdftron.pdf.tools.ToolManager;

/**
 * Square markup with Bauhub subject / appearance. Keeps stock {@link RectCreate} init so drawing
 * gestures behave like the SDK default; prefs for preview colors come from {@link BauhubShapeMarkupStyle#syncShapeCreationStyleToToolStyleConfig}.
 */
public class BauhubAreaMarkupTool extends RectCreate {

    public static final ToolManager.ToolModeBase MODE =
            ToolManager.ToolMode.addNewMode(Annot.e_Square);

    private String bauhubSubject = "Comment";

    public BauhubAreaMarkupTool(@NonNull PDFViewCtrl ctrl) {
        super(ctrl);
        // RectCreate forces fill on; SimpleShapeCreate then applies stroke opacity to fill paint → solid white.
        mHasFill = false;
        BauhubShapeMarkupStyle.syncShapeCreationStyleToToolStyleConfig(ctrl.getContext());
    }

    public void configure(String subject) {
        this.bauhubSubject = subject != null ? subject : "Comment";
    }

    /**
     * 1-based page where the user started the shape ({@link com.pdftron.pdf.tools.SimpleShapeCreate#mDownPageNum}).
     * Used for decorative pin placement when the new annot is not yet linked to a {@link com.pdftron.pdf.Page}
     * — {@link PDFViewCtrl#getCurrentPage()} can be the wrong page in continuous / zoomed-out layouts.
     */
    public int getBauhubShapeCreationPageNum() {
        return mDownPageNum;
    }

    /** Ensures prefs/fields used by {@code SimpleShapeCreate#onDown} have non-zero opacity before paint setup. */
    @Override
    public boolean onDown(MotionEvent e) {
        AnnotStyle style = new AnnotStyle();
        BauhubShapeMarkupStyle.configureRubberBandAnnotStyle(style, Annot.e_Square);
        setupAnnotProperty(style);
        return super.onDown(e);
    }

    @Override
    public void setupAnnotProperty(AnnotStyle annotStyle) {
        BauhubShapeMarkupStyle.configureRubberBandAnnotStyle(annotStyle, Annot.e_Square);
        super.setupAnnotProperty(annotStyle);
    }

    @Override
    public ToolManager.ToolModeBase getToolMode() {
        return MODE;
    }

    @Override
    protected Annot createMarkup(PDFDoc doc, Rect rect) throws PDFNetException {
        Annot annot = super.createMarkup(doc, rect);
        BauhubShapeMarkupStyle.apply(this, annot, bauhubSubject);
        BauhubShapeMarkupStyle.scheduleDeferredAreaMarkupStyleReapply(this, annot, bauhubSubject);
        return annot;
    }
}
