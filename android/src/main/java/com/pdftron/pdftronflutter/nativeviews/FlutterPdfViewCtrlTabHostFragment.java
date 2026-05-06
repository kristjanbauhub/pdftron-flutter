package com.pdftron.pdftronflutter.nativeviews;

import android.os.Bundle;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.FragmentActivity;

import com.pdftron.pdf.controls.PdfViewCtrlTabHostFragment2;

public class FlutterPdfViewCtrlTabHostFragment extends PdfViewCtrlTabHostFragment2 {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        FragmentActivity activity = getActivity();
        if (activity != null) {
            applyTheme(activity);
        }

        super.onCreate(savedInstanceState);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        pinNativeAnnotationToolbarToTop();
    }

    @Override
    public void onTabDocumentLoaded(String tag) {
        super.onTabDocumentLoaded(tag);
        // Re-pin after the toolbar component finishes inflating. `setAnnotationToolbarPosition`
        // in `onViewCreated` fires before PDFTron's internal `inflateToolbarState` runs on some
        // devices, which resets the position back to the default (BOTTOM on phones). Calling it
        // again once the document is loaded guarantees the final layout has the native annotation
        // toolbar + preset bar at the top.
        pinNativeAnnotationToolbarToTop();
    }

    /**
     * Pin the native annotation toolbar (and its companion preset / color-picker bar) to the top
     * of the viewer. Bauhub overlays its own annotation chrome at the bottom of the screen
     * (geometry bar, activity-feed FAB, polygon "Valmis" FAB, etc.), and PDFTron's default
     * position for the preset bar on phones is the bottom — which meant the native color row was
     * drawing behind our overlay and effectively invisible while the user was creating a stock
     * annotation. Moving both bars to the TOP (right under the app bar) keeps them reachable for
     * native annotation creation without colliding with our custom UI.
     */
    private void pinNativeAnnotationToolbarToTop() {
        try {
            if (getAnnotationToolbarPosition() != AnnotationToolbarPosition.TOP) {
                setAnnotationToolbarPosition(AnnotationToolbarPosition.TOP);
            }
        } catch (Exception ignored) {
            // Older PDFTron builds without the positioning API fall back to the default layout.
        }
    }

    @Override
    protected void updateFullScreenModeLayout() {
        if (isInFullScreenMode()) {
            super.updateFullScreenModeLayout();
        }
        // do nothing if not in full screen mode
    }
}
