package com.pdftron.pdftronflutter.bauhub;

import android.content.Context;

import androidx.annotation.NonNull;

import com.pdftron.pdftronflutter.R;

/**
 * Comment / attachment area pins use the same PNG artwork as iOS {@code bauhubCommentPin} /
 * {@code bauhubAttachmentPin} ({@code res/raw/bauhub_comment_pin.png},
 * {@code res/raw/bauhub_attachment_pin.png}), decoded and upscaled for PDF embedding.
 * Task area pins use {@code task_dd1111.png} (or {@code task_111111} fallback), matching iOS
 * {@code task_dd1111}.
 */
public final class BauhubWebPinAssets {

    private BauhubWebPinAssets() {
    }

    /** Web {@code taskPinColor} — not {@link android.graphics.Color} from project category. */
    public static int taskStampRawId(@NonNull Context ctx) {
        int id = ctx.getResources().getIdentifier("task_dd1111", "raw", ctx.getPackageName());
        return id != 0 ? id : R.raw.task_111111;
    }

    @NonNull
    public static String taskStampBaseName(@NonNull Context ctx) {
        int id = ctx.getResources().getIdentifier("task_dd1111", "raw", ctx.getPackageName());
        return id != 0 ? "task_dd1111" : "task_111111";
    }
}
