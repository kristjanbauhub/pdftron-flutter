package com.pdftron.pdf.tools;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.pdftron.pdf.PDFViewCtrl;

/**
 * {@link Tool#mPdfViewCtrl} is protected and has no public getter; same-package access for Bauhub code.
 */
public final class BauhubToolsAccess {
    private BauhubToolsAccess() {
    }

    @Nullable
    public static PDFViewCtrl getPdfViewCtrl(@NonNull Tool tool) {
        return tool.mPdfViewCtrl;
    }
}
