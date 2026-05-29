package com.pdftron.pdftronflutter.bauhub;

import android.content.Context;
import android.graphics.Color;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import com.pdftron.common.PDFNetException;
import com.pdftron.pdf.config.ToolStyleConfig;
import com.pdftron.pdf.Annot;
import com.pdftron.pdf.ColorPt;
import com.pdftron.pdf.ColorSpace;
import com.pdftron.pdf.Element;
import com.pdftron.pdf.ElementBuilder;
import com.pdftron.pdf.ElementWriter;
import com.pdftron.pdf.GState;
import com.pdftron.pdf.PDFDoc;
import com.pdftron.pdf.PDFViewCtrl;
import com.pdftron.pdf.Page;
import com.pdftron.pdf.Point;
import com.pdftron.pdf.Rect;
import com.pdftron.pdf.annots.Markup;
import com.pdftron.pdf.annots.PolyLine;
import com.pdftron.pdf.model.AnnotStyle;
import com.pdftron.pdf.model.ShapeBorderStyle;
import com.pdftron.pdf.tools.BauhubToolsAccess;
import com.pdftron.pdf.tools.Tool;
import com.pdftron.pdf.tools.ToolManager;
import com.pdftron.pdf.utils.AnalyticsHandlerAdapter;
import com.pdftron.pdf.utils.Utils;
import com.pdftron.sdf.Obj;

import java.util.Locale;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import androidx.annotation.Nullable;

/**
 * Bauhub square/polygon: translucent fill (~0.3) + thin opaque stroke (matches web canvas + XFDF {@code opacity="0.3"}).
 */
public final class BauhubShapeMarkupStyle {

    private static volatile int sFillArgb = 0xFF2368E5;
    private static volatile int sStrokeArgb = 0xFF2368E5;
    /**
     * Custom Bauhub fill lives in {@code AP/N}; the annotation's {@code IC} is also kept at the
     * **opaque** brand colour so that web / iOS (which read XFDF and apply
     * {@code opacity="0.3"} themselves) render the identical translucent fill. We cache the
     * design colour here as a fall-back source when {@code IC} cannot be read for some reason
     * (bad RGB component count, decode failure) so reapply still produces a correct AP.
     */
    private static final ConcurrentHashMap<Long, Integer> BAUHUB_AREA_OPAQUE_FILL_ARGB_BY_OBJ =
            new ConcurrentHashMap<>();
    private static final double STROKE_WIDTH = 1.0;
    /**
     * Rubber-band stroke width (PDF points) for shape-create preview — thin outline only; committed markup uses {@link #STROKE_WIDTH}.
     */
    private static final float RUBBER_BAND_STROKE_PT = 1.5f;
    private static final double FILL_DISPLAY_OPACITY = 0.3;
    /** {@link #trySetTranslucentAreaMarkupAppearance} skips tiny rects; committed markup uses 0.5 PDF units. */
    private static final double MIN_SQUARE_SIDE_FOR_TRANSLUCENT_AP = 0.5;

    private BauhubShapeMarkupStyle() {
    }

    public static void setPresetColors(int fillArgb, int strokeArgb) {
        setPresetColors(fillArgb, strokeArgb, null);
    }

    /**
     * Updates static presets and persists square/polygon creation styles so the **rubber-band overlay**
     * (canvas) matches Bauhub colors — not only the PDF annot. Apryse defaults square creation to a
     * red border via {@link ToolStyleConfig} / SharedPreferences until {@link #syncShapeCreationStyleToToolStyleConfig}
     * runs.
     */
    public static void setPresetColors(int fillArgb, int strokeArgb, @Nullable Context context) {
        sFillArgb = 0xFF000000 | (fillArgb & 0xFFFFFF);
        sStrokeArgb = 0xFF000000 | (strokeArgb & 0xFFFFFF);
        syncShapeCreationStyleToToolStyleConfig(context);
    }

    /**
     * Writes Bauhub stroke/fill/thickness into {@link ToolStyleConfig} for square and polygon create
     * tools so in-progress drawing uses the same colors as committed Bauhub markup (not SDK red).
     * <p>
     * Custom tools use {@link ToolManager.ToolMode#addNewMode(int)}; the viewer loads
     * {@link ToolStyleConfig} with a non-empty {@code extraTag} derived from
     * {@link ToolManager.ToolModeBase#getValue()}. Saving only with tag {@code ""} left the rubber band
     * with no effective stroke/fill for {@link BauhubAreaMarkupTool} / {@link BauhubPolygonMarkupTool}.
     */
    public static void syncShapeCreationStyleToToolStyleConfig(@Nullable Context context) {
        if (context == null) {
            return;
        }
        try {
            saveRubberBandAnnotStylesToToolStyleConfig(context, "");
            saveRubberBandAnnotStylesToToolStyleConfig(
                    context, String.valueOf(BauhubAreaMarkupTool.MODE.getValue()));
            saveRubberBandAnnotStylesToToolStyleConfig(
                    context, String.valueOf(BauhubPolygonMarkupTool.MODE.getValue()));
            saveRubberBandAnnotStylesToToolStyleConfig(
                    context, BauhubAreaMarkupTool.MODE.toString());
            saveRubberBandAnnotStylesToToolStyleConfig(
                    context, BauhubPolygonMarkupTool.MODE.toString());
        } catch (Exception e) {
            AnalyticsHandlerAdapter.getInstance().sendException(e);
        }
    }

    private static void saveRubberBandAnnotStylesToToolStyleConfig(
            @NonNull Context context, @NonNull String extraTag) {
        ToolStyleConfig cfg = ToolStyleConfig.getInstance();
        AnnotStyle square = new AnnotStyle();
        square.setAnnotType(Annot.e_Square);
        square.setStrokeColor(rubberBandStrokeArgbForShapeCreateTool());
        square.setFillColor(rubberBandFillArgbTransparentForShapeCreateTool());
        square.setThickness(RUBBER_BAND_STROKE_PT);
        cfg.saveAnnotStyle(context, square, extraTag);
        AnnotStyle polygon = new AnnotStyle();
        polygon.setAnnotType(Annot.e_Polygon);
        polygon.setStrokeColor(rubberBandStrokeArgbForShapeCreateTool());
        polygon.setFillColor(rubberBandFillArgbTransparentForShapeCreateTool());
        polygon.setThickness(RUBBER_BAND_STROKE_PT);
        cfg.saveAnnotStyle(context, polygon, extraTag);
    }

    /** Preset stroke from Flutter / viewer config — used while drawing area markup rubber band. */
    public static int getPresetStrokeArgb() {
        return sStrokeArgb;
    }

    /** Preset fill from Flutter / viewer config — used while drawing area markup rubber band. */
    public static int getPresetFillArgb() {
        return sFillArgb;
    }

    /** Opaque stroke color for {@link com.pdftron.pdf.tools.Tool#setupAnnotProperty(int, float, float, int, String, String)}. */
    public static int presetStrokeColorArgbForShapeCreateTool() {
        return 0xFF000000 | (sStrokeArgb & 0xFFFFFF);
    }

    /** ~30% alpha fill for shape-create rubber band (matches committed markup). */
    public static int presetFillColorArgbTranslucentForShapeCreateTool() {
        int f = sFillArgb;
        return Color.argb(77, Color.red(f), Color.green(f), Color.blue(f));
    }

    /**
     * While dragging, use a simple black outline + fully transparent fill (not Bauhub brand colors) so the
     * preview is always visible; committed markup still uses {@link #apply}.
     */
    public static int rubberBandStrokeArgbForShapeCreateTool() {
        return 0xFF000000;
    }

    public static int rubberBandFillArgbTransparentForShapeCreateTool() {
        // Fully transparent; Bauhub tools set {@code mHasFill = false} so fill is not drawn (SDK applies
        // {@code mOpacity} to fill paint, which would turn any light fill into solid white).
        return Color.TRANSPARENT;
    }

    /** Stroke width (PDF points) for RectCreate / PolygonCreate — must match {@link #syncShapeCreationStyleToToolStyleConfig}. */
    public static float rubberBandStrokePt() {
        return RUBBER_BAND_STROKE_PT;
    }

    /**
     * Configures {@link AnnotStyle} for the in-progress rectangle/polygon overlay. The SDK’s
     * {@link com.pdftron.pdf.tools.Tool#setupAnnotProperty(int, float, float, int, String, String)} is a no-op;
     * only {@link com.pdftron.pdf.tools.SimpleShapeCreate#setupAnnotProperty(AnnotStyle)} copies fields into
     * {@code mPaint} / {@code mStrokeColor}. Opacity must be {@code 1f}: {@code onDown} applies
     * {@code Paint.setAlpha((int)(255 * mOpacity))}, so {@code 0} makes the stroke invisible.
     */
    public static void configureRubberBandAnnotStyle(@NonNull AnnotStyle style, int annotType) {
        style.setAnnotType(annotType);
        style.setStrokeColor(rubberBandStrokeArgbForShapeCreateTool());
        style.setFillColor(rubberBandFillArgbTransparentForShapeCreateTool());
        style.setThickness(RUBBER_BAND_STROKE_PT);
        style.setOpacity(1f);
        style.setBorderStyle(ShapeBorderStyle.DEFAULT);
    }

    private static long sdfObjNumOrNeg1(Annot annot) {
        try {
            Obj o = annot.getSDFObj();
            if (o == null || o.isNull()) {
                return -1;
            }
            return o.getObjNum();
        } catch (Exception e) {
            return -1;
        }
    }

    private static void rememberBauhubAreaOpaqueFillArgb(Annot annot, int opaqueArgb) {
        long k = sdfObjNumOrNeg1(annot);
        if (k >= 0) {
            BAUHUB_AREA_OPAQUE_FILL_ARGB_BY_OBJ.put(k, opaqueArgb);
        }
    }

    private static int cachedBauhubAreaOpaqueFillArgb(Annot annot, int fallbackArgb) {
        long k = sdfObjNumOrNeg1(annot);
        if (k < 0) {
            return fallbackArgb;
        }
        Integer v = BAUHUB_AREA_OPAQUE_FILL_ARGB_BY_OBJ.get(k);
        return v != null ? v : fallbackArgb;
    }

    /**
     * Stores the **opaque** brand fill colour as the annotation's {@code IC} (interior colour).
     * This is the value web and iOS read from the exported XFDF — they apply their own
     * {@code opacity="0.3"} on top, so {@code IC} must be the design colour at full saturation.
     * Writing a white-blended pastel here (an earlier Android-only workaround for PDFTron's
     * {@code AnnotEdit} overlay rendering during selection) caused web / iOS to render
     * {@code blended × 0.3} — a washed-out very light fill. The fix is twofold:
     * <ul>
     *   <li>Android no longer needs a blended {@code IC} because
     *       {@code ToolManager.setRealTimeAnnotEdit(false)} (set in [ViewerImpl]) suppresses
     *       the {@code AnnotView} overlay during selection — the page-level custom {@code AP/N}
     *       (with {@code fill 0.3 + stroke 1.0} baked in) keeps rendering, so {@code IC} no
     *       longer affects what the user sees on Android.</li>
     *   <li>Cross-platform parity: web / iOS render {@code IC × opacity = opaque × 0.3 =
     *       translucent} — identical to Android's AP rendering. No more
     *       lighter-after-Android-edit reports.</li>
     * </ul>
     * <p>Hit-testing: a non-empty {@code IC} still makes the whole polygon interior tappable
     * (vs. only the thin stroke when {@code IC} is missing) — so opaque {@code IC} is strictly
     * better than stripped {@code IC} for both visuals and tap behaviour.
     * <p>{@link #opaqueFillForTranslucentCustomStream} continues to round-trip blended {@code IC}
     * values from older Android saves back to opaque on import — backward-compatible.
     */
    private static void setOpaqueInteriorColorAfterBauhubCustomAp(
            @NonNull Annot annot, int opaqueFillArgb) {
        try {
            Markup m = new Markup(annot);
            m.setInteriorColor(argbToColorPt(opaqueFillArgb), 3);
        } catch (Exception ignored) {
        }
    }

    /**
     * PDFTron may rebuild the square/polygon appearance after {@code RectCreate} / {@code PolygonCreate}
     * finishes; iOS reapplies Bauhub style on a short delay — mirror that so Android keeps translucent
     * fill + preset colors instead of default red stroke.
     */
    public static void scheduleDeferredAreaMarkupStyleReapply(
            @NonNull Tool tool, @NonNull Annot annot, @Nullable String subject) {
        PDFViewCtrl ctrl = BauhubToolsAccess.getPdfViewCtrl(tool);
        if (ctrl == null) {
            return;
        }
        final String subj = subject != null ? subject : "Comment";
        Handler h = new Handler(Looper.getMainLooper());
        Runnable r = () -> {
            try {
                if (!annot.isValid()) {
                    return;
                }
                PDFViewCtrl c = BauhubToolsAccess.getPdfViewCtrl(tool);
                if (c == null) {
                    return;
                }
                boolean shouldUnlock = false;
                try {
                    c.docLock(true);
                    shouldUnlock = true;
                    BauhubShapeMarkupStyle.apply(tool, annot, subj);
                } catch (PDFNetException e) {
                    AnalyticsHandlerAdapter.getInstance().sendException(e);
                } finally {
                    if (shouldUnlock) {
                        c.docUnlock();
                    }
                }
            } catch (Exception e) {
                AnalyticsHandlerAdapter.getInstance().sendException(e);
            }
        };
        h.post(r);
        h.postDelayed(r, 85);
    }

    private static final Pattern BAUHUB_AREA_SUBJECT_ATTR = Pattern.compile("(?i)subject\\s*=\\s*[\"'](Comment|Attachment|Task)[\"']");

    private static boolean xfdfAttributeStringHasBauhubAreaSubject(@Nullable String attrs) {
        return attrs != null && BAUHUB_AREA_SUBJECT_ATTR.matcher(attrs).find();
    }

    /** {@code <squareattrs>} is invalid; ensure a leading space before the attribute list when missing. */
    private static String xfdfAttrsWithLeadingSpace(@Nullable String attrs) {
        if (attrs == null || attrs.isEmpty()) {
            return attrs;
        }
        if (Character.isWhitespace(attrs.charAt(0))) {
            return attrs;
        }
        return " " + attrs;
    }

    private static final int TRN_CHILD_FLAGS = Pattern.CASE_INSENSITIVE | Pattern.DOTALL;

    /** Precompiled; same repair steps as pdftron-flutter iOS and Dart import sanitizer. */
    private static final Pattern BAUHUB_REPAIR_TRN_OPEN_BEFORE_TRN = Pattern.compile(
            "<trn-custom-data(\\b[^>]*?)\"\\s*>\\s*<trn-custom-data", TRN_CHILD_FLAGS);
    private static final Pattern BAUHUB_REPAIR_SPURIOUS_CLOSE_BEFORE_APREF = Pattern.compile(
            "((?:<(?:[\\w.-]+:)?trn-custom-data\\b[^>]*/\\s*>\\s*)+)</[\\w.:-]*(square|polygon)\\s*>\\s*(<apref\\b)",
            TRN_CHILD_FLAGS);

    /**
     * PDFNet can serialize the first {@code trn-custom-data} as an opening tag (stray {@code >} before the next element)
     * and emit {@code </square>} before {@code <apref>} — invalid XML. Fix before normalize/import.
     */
    private static String repairSquarePolygonTrnCustomDataXfdfMerging(String xfdf) {
        if (xfdf.isEmpty()) {
            return xfdf;
        }
        Matcher m1 = BAUHUB_REPAIR_TRN_OPEN_BEFORE_TRN.matcher(xfdf);
        StringBuffer sb1 = new StringBuffer();
        while (m1.find()) {
            m1.appendReplacement(sb1, Matcher.quoteReplacement("<trn-custom-data" + m1.group(1) + "\"/><trn-custom-data"));
        }
        m1.appendTail(sb1);
        String out = sb1.toString();

        Matcher m2 = BAUHUB_REPAIR_SPURIOUS_CLOSE_BEFORE_APREF.matcher(out);
        StringBuffer sb2 = new StringBuffer();
        while (m2.find()) {
            m2.appendReplacement(sb2, Matcher.quoteReplacement(m2.group(1) + m2.group(3)));
        }
        m2.appendTail(sb2);
        return sb2.toString();
    }

    /**
     * Normalizes self-closing {@code <square/>} / {@code <polygon/>} and empty paired {@code <square></square>} XFDF
     * from mobile to match WebViewer-style attributes (opacity 0.3, {@code dashes=""}). When {@code interior-color}
     * is missing or matches stroke {@code color}, sets interior to stroke; otherwise preserves a distinct fill.
     * Emits self-closing tags only — PDFNet mobile import rejects a {@code trn-custom-data} child inside square/polygon.
     */
    @Nullable
    public static String normalizeBauhubAreaMarkupXfdfForWebParity(@Nullable String xfdf) {
        if (xfdf == null || xfdf.isEmpty()) {
            return xfdf;
        }
        xfdf = repairSquarePolygonTrnCustomDataXfdfMerging(xfdf);
        Pattern opDouble = Pattern.compile("(?i)\\bopacity\\s*=\\s*\"[^\"]*\"");
        Pattern opSingle = Pattern.compile("(?i)\\bopacity\\s*=\\s*'[^']*'");
        Pattern colorRe = Pattern.compile("(?i)\\bcolor\\s*=\\s*\"(#?[0-9A-Fa-f]{6})\"");
        Pattern intRe = Pattern.compile("(?i)\\binterior-color\\s*=\\s*\"[^\"]*\"");
        Pattern dashesProbe = Pattern.compile("(?i)\\bdashes\\s*=");

        String afterSelf = normalizeBauhubAreaMarkupSelfClosingTags(xfdf, opDouble, opSingle, colorRe, intRe, dashesProbe);
        return normalizeBauhubAreaMarkupPairedEmptyTags(afterSelf, opDouble, opSingle, colorRe, intRe, dashesProbe);
    }

    private static final String[] BAUHUB_DENORM_TRN_PATTERNS = {
        "(?is)<([\\w.:-]*square)(\\s[^>]*?)>\\s*<(?:[\\w.-]+:)?trn-custom-data\\b[\\s\\S]*?/\\s*>\\s*</[\\w.:-]*square\\s*>",
        "(?is)<([\\w.:-]*polygon)(\\s[^>]*?)>\\s*<(?:[\\w.-]+:)?trn-custom-data\\b[\\s\\S]*?/\\s*>\\s*</[\\w.:-]*polygon\\s*>",
        "(?is)<([\\w.:-]*square)(\\s[^>]*?)>\\s*<(?:[\\w.-]+:)?trn-custom-data\\b[\\s\\S]*?</(?:[\\w.-]+:)?trn-custom-data\\s*>\\s*</[\\w.:-]*square\\s*>",
        "(?is)<([\\w.:-]*polygon)(\\s[^>]*?)>\\s*<(?:[\\w.-]+:)?trn-custom-data\\b[\\s\\S]*?</(?:[\\w.-]+:)?trn-custom-data\\s*>\\s*</[\\w.:-]*polygon\\s*>",
    };

    private static final String[] BAUHUB_STRIP_ORPHAN_CLOSE_PATTERNS = {
        "(?is)(<[\\w.:-]*square\\b[^>]*/\\s*>)\\s*<(?:[\\w.-]+:)?trn-custom-data\\b[\\s\\S]*?/\\s*>\\s*</[\\w.:-]*square\\s*>",
        "(?is)(<[\\w.:-]*square\\b[^>]*/\\s*>)\\s*</[\\w.:-]*square\\s*>",
        "(?is)(<[\\w.:-]*polygon\\b[^>]*/\\s*>)\\s*<(?:[\\w.-]+:)?trn-custom-data\\b[\\s\\S]*?/\\s*>\\s*</[\\w.:-]*polygon\\s*>",
        "(?is)(<[\\w.:-]*polygon\\b[^>]*/\\s*>)\\s*</[\\w.:-]*polygon\\s*>",
    };

    private static String stripOrphanClosingAfterSelfClosedAreaMarkup(String xfdf) {
        String out = xfdf;
        for (int pass = 0; pass < 32; pass++) {
            String before = out;
            for (String p : BAUHUB_STRIP_ORPHAN_CLOSE_PATTERNS) {
                Matcher m = Pattern.compile(p, TRN_CHILD_FLAGS).matcher(out);
                StringBuffer sb = new StringBuffer();
                while (m.find()) {
                    m.appendReplacement(sb, Matcher.quoteReplacement(m.group(1)));
                }
                m.appendTail(sb);
                out = sb.toString();
            }
            if (out.equals(before)) {
                break;
            }
        }
        return out;
    }

    /**
     * PDFNet mobile XFDF import does not accept WebViewer-style {@code <square><trn-custom-data/></square>}.
     * Handles optional XML prefixes (e.g. xfdf:square) and uses {@code [\s\S]*?} so trn-custom-data attributes cannot break {@code [^>]*}.
     */
    @Nullable
    public static String denormalizeBauhubAreaMarkupXfdfForMobileImport(@Nullable String xfdf) {
        if (xfdf == null || xfdf.isEmpty()) {
            return xfdf;
        }
        xfdf = repairSquarePolygonTrnCustomDataXfdfMerging(xfdf);
        String out = stripOrphanClosingAfterSelfClosedAreaMarkup(xfdf);
        for (int pass = 0; pass < 32; pass++) {
            String before = out;
            for (String p : BAUHUB_DENORM_TRN_PATTERNS) {
                Matcher m = Pattern.compile(p, TRN_CHILD_FLAGS).matcher(out);
                StringBuffer sb = new StringBuffer();
                while (m.find()) {
                    String repl = "<" + m.group(1) + m.group(2) + "/>";
                    m.appendReplacement(sb, Matcher.quoteReplacement(repl));
                }
                m.appendTail(sb);
                out = sb.toString();
            }
            if (out.equals(before)) {
                break;
            }
        }
        return stripOrphanClosingAfterSelfClosedAreaMarkup(out);
    }

    private static String normalizeBauhubAreaMarkupSelfClosingTags(
            String xfdf,
            Pattern opDouble,
            Pattern opSingle,
            Pattern colorRe,
            Pattern intRe,
            Pattern dashesProbe) {
        Pattern tag = Pattern.compile("<(square|polygon)\\s([\\s\\S]*?)/\\s*>", Pattern.CASE_INSENSITIVE);
        Matcher m = tag.matcher(xfdf);
        StringBuffer sb = new StringBuffer();
        while (m.find()) {
            String name = m.group(1);
            String attrs = m.group(2);
            if (!xfdfAttributeStringHasBauhubAreaSubject(attrs)) {
                m.appendReplacement(sb, Matcher.quoteReplacement(m.group(0)));
                continue;
            }
            String newAttrs = buildNormalizedBauhubAreaMarkupAttrs(attrs, opDouble, opSingle, colorRe, intRe, dashesProbe);
            String repl = "<" + name + xfdfAttrsWithLeadingSpace(newAttrs) + "/>";
            m.appendReplacement(sb, Matcher.quoteReplacement(repl));
        }
        m.appendTail(sb);
        return sb.toString();
    }

    private static String normalizeBauhubAreaMarkupPairedEmptyTags(
            String xfdf,
            Pattern opDouble,
            Pattern opSingle,
            Pattern colorRe,
            Pattern intRe,
            Pattern dashesProbe) {
        Pattern paired = Pattern.compile("<(square|polygon)(\\s[^>]*?)>\\s*</\\1\\s*>", Pattern.CASE_INSENSITIVE);
        Matcher m = paired.matcher(xfdf);
        StringBuffer sb = new StringBuffer();
        while (m.find()) {
            String name = m.group(1);
            String attrs = m.group(2);
            if (!xfdfAttributeStringHasBauhubAreaSubject(attrs)) {
                m.appendReplacement(sb, Matcher.quoteReplacement(m.group(0)));
                continue;
            }
            String newAttrs = buildNormalizedBauhubAreaMarkupAttrs(attrs, opDouble, opSingle, colorRe, intRe, dashesProbe);
            String repl = "<" + name + xfdfAttrsWithLeadingSpace(newAttrs) + "/>";
            m.appendReplacement(sb, Matcher.quoteReplacement(repl));
        }
        m.appendTail(sb);
        return sb.toString();
    }

    private static String buildNormalizedBauhubAreaMarkupAttrs(
            String attrs,
            Pattern opDouble,
            Pattern opSingle,
            Pattern colorRe,
            Pattern intRe,
            Pattern dashesProbe) {
        String newAttrs = attrs;
        if (opDouble.matcher(newAttrs).find()) {
            newAttrs = opDouble.matcher(newAttrs).replaceAll("opacity=\"0.3\"");
        } else if (opSingle.matcher(newAttrs).find()) {
            newAttrs = opSingle.matcher(newAttrs).replaceAll("opacity='0.3'");
        } else {
            newAttrs = " opacity=\"0.3\" " + newAttrs;
        }
        if (!dashesProbe.matcher(newAttrs).find()) {
            newAttrs = " dashes=\"\" " + newAttrs;
        }
        Pattern intHexAttrRe = Pattern.compile("(?i)\\binterior-color\\s*=\\s*\"(#?[0-9A-Fa-f]{6})\"");
        Matcher cm = colorRe.matcher(newAttrs);
        if (cm.find()) {
            String strokeHex = cm.group(1);
            Matcher intHexM = intHexAttrRe.matcher(newAttrs);
            String interiorHex = intHexM.find() ? intHexM.group(1) : null;
            boolean distinctInterior =
                    interiorHex != null
                            && strokeHex != null
                            && !bauhubHex6EqualIgnoreCase(interiorHex, strokeHex);
            if (distinctInterior) {
                return newAttrs;
            }
            String hex = strokeHex;
            if (hex != null && !hex.isEmpty() && !hex.startsWith("#")) {
                hex = "#" + hex;
            }
            if (hex != null && !hex.isEmpty()) {
                String icVal = "interior-color=\"" + hex + "\"";
                if (intRe.matcher(newAttrs).find()) {
                    newAttrs = intRe.matcher(newAttrs).replaceAll(Matcher.quoteReplacement(icVal));
                } else {
                    newAttrs = " " + icVal + " " + newAttrs;
                }
            }
        }
        return newAttrs;
    }

    private static String normalizeHex6ForCompare(String hex) {
        if (hex == null || hex.isEmpty()) {
            return "";
        }
        String h = hex.trim();
        if (!h.startsWith("#")) {
            h = "#" + h;
        }
        return h.toUpperCase(Locale.US);
    }

    private static boolean bauhubHex6EqualIgnoreCase(String a, String b) {
        return normalizeHex6ForCompare(a).equals(normalizeHex6ForCompare(b));
    }

    public static void apply(Tool tool, Annot annot, String subject) throws PDFNetException {
        if (annot == null || !annot.isMarkup()) {
            return;
        }
        ensureBauhubAnnotHasUniqueId(tool, annot);
        Markup markup = new Markup(annot);
        if (subject != null && !subject.isEmpty()) {
            markup.setSubject(subject);
        }
        ColorPt fillOpaque = argbToColorPt(sFillArgb);
        ColorPt stroke = argbToColorPt(sStrokeArgb);
        annot.setColor(stroke, 3);
        // CA = 1.0; translucency is baked into the AP fill alpha (matches iOS / web XFDF parity:
        // unselected render = AP × 1.0 = (fill 0.3, stroke 1.0)). Setting CA < 1.0 here also
        // dimmed the stroke to 0.3, which users perceived as a "faded outline" on non-white pages.
        markup.setOpacity(1.0);
        try {
            Annot.BorderStyle bs = annot.getBorderStyle();
            if (bs != null) {
                bs.setWidth(STROKE_WIDTH);
                annot.setBorderStyle(bs);
            } else {
                Annot.BorderStyle created = new Annot.BorderStyle(Annot.BorderStyle.e_solid, 1, 0, 0);
                try {
                    annot.setBorderStyle(created);
                } finally {
                    created.destroy();
                }
            }
        } catch (Exception ignored) {
        }
        PDFViewCtrl ctrlForAuthor = BauhubToolsAccess.getPdfViewCtrl(tool);
        if (ctrlForAuthor != null) {
            ToolManager tm = (ToolManager) ctrlForAuthor.getToolManager();
            if (tm != null) {
                Tool.setAuthorForAnnot(tm, markup);
            }
        }
        PDFDoc doc = ctrlForAuthor != null ? ctrlForAuthor.getDoc() : null;
        double lineW = STROKE_WIDTH;
        try {
            Annot.BorderStyle bs2 = annot.getBorderStyle();
            if (bs2 != null && bs2.getWidth() > 0.1) {
                lineW = bs2.getWidth();
            }
        } catch (Exception ignored) {
        }
        // fillOpacity = FILL_DISPLAY_OPACITY: bake 0.3 fill alpha + 1.0 stroke alpha into the AP.
        boolean customOk =
                doc != null
                        && trySetTranslucentAreaMarkupAppearance(
                                doc,
                                annot,
                                fillOpaque,
                                stroke,
                                FILL_DISPLAY_OPACITY,
                                lineW,
                                MIN_SQUARE_SIDE_FOR_TRANSLUCENT_AP);
        if (customOk) {
            // Avoid drawing the default square border on top of the custom appearance stream (thick red outline).
            zeroSquarePolygonBorderWidthForCustomAppearance(annot);
            rememberBauhubAreaOpaqueFillArgb(annot, rgbArgbFromColorPt(fillOpaque));
            setOpaqueInteriorColorAfterBauhubCustomAp(annot, rgbArgbFromColorPt(fillOpaque));
        } else {
            // Fallback (no custom AP): keep IC as the OPAQUE design colour so the exported XFDF
            // matches web/iOS expectations (they apply opacity="0.3" themselves). Lower CA to
            // 0.3 so Android's default Square/Polygon render still looks translucent — it would
            // otherwise paint IC at full alpha. The custom-AP path above keeps CA = 1.0; only this
            // fallback path needs the CA reduction because the AP isn't carrying the alpha for us.
            markup.setInteriorColor(argbToColorPt(rgbArgbFromColorPt(fillOpaque)), 3);
            try {
                markup.setOpacity(FILL_DISPLAY_OPACITY);
            } catch (Exception ignored) {
            }
            try {
                annot.refreshAppearance();
            } catch (Exception ignored) {
            }
        }
        // Match WebViewer XFDF date format (local timezone offset) on the area shape itself.
        // Flags stay at PDFTron default (print) — web emits the same for square/polygon.
        BauhubWebStyleXfdf.applyToShape(annot);
        BauhubAreaPinDecoration.ensurePinForNewShape(tool, annot);
        refreshAreaMarkupViewOnly(tool, annot);
    }

    /**
     * Rebuilds translucent custom appearance for one annot if it is a Bauhub square/polygon area.
     * Caller must hold a write lock on {@link PDFDoc} / {@link PDFViewCtrl} as for other mutators.
     *
     * <p>Used after selection on Android: a full-document reapply is heavy and can interact badly
     * with hit-testing; refreshing only the selected markup restores the fill without walking every page.
     */
    public static void reapplyBauhubAreaAppearanceForAnnot(PDFDoc doc, Annot annot) {
        if (doc == null || annot == null) {
            return;
        }
        try {
            if (!annot.isValid() || !annot.isMarkup()) {
                return;
            }
            int t = annot.getType();
            if (t != Annot.e_Square && t != Annot.e_Polygon) {
                return;
            }
            Markup markup = new Markup(annot);
            String subj = null;
            try {
                subj = markup.getSubject();
            } catch (Exception ignored) {
            }
            if (!isBauhubAreaSubject(subj)) {
                return;
            }
            ColorPt fillPt;
            try {
                int icn = markup.getInteriorColorCompNum();
                fillPt =
                        icn >= 3
                                ? markup.getInteriorColor()
                                : argbToColorPt(cachedBauhubAreaOpaqueFillArgb(annot, sFillArgb));
            } catch (Exception e) {
                fillPt = argbToColorPt(cachedBauhubAreaOpaqueFillArgb(annot, sFillArgb));
            }
            ColorPt strokePt;
            try {
                int ccn = annot.getColorCompNum();
                strokePt = ccn >= 3 ? annot.getColorAsRGB() : argbToColorPt(sStrokeArgb);
            } catch (Exception e) {
                strokePt = argbToColorPt(sStrokeArgb);
            }
            double lineW = STROKE_WIDTH;
            try {
                Annot.BorderStyle bs = annot.getBorderStyle();
                if (bs != null && bs.getWidth() > 0.1) {
                    lineW = bs.getWidth();
                }
            } catch (Exception ignored) {
            }
            try {
                // CA = 1.0; translucency is baked into the AP fill alpha (matches iOS / web XFDF
                // parity). See [apply] for full reasoning.
                markup.setOpacity(1.0);
            } catch (Exception ignored) {
            }
            ColorPt fillOpaqueForAp = opaqueFillForTranslucentCustomStream(fillPt);
            // fillOpacity = FILL_DISPLAY_OPACITY: AP bakes (fill 0.3 alpha, stroke 1.0 alpha).
            boolean ok =
                    trySetTranslucentAreaMarkupAppearance(
                            doc,
                            annot,
                            fillOpaqueForAp,
                            strokePt,
                            FILL_DISPLAY_OPACITY,
                            lineW,
                            MIN_SQUARE_SIDE_FOR_TRANSLUCENT_AP);
            if (!ok) {
                ok =
                        trySetTranslucentAreaMarkupAppearance(
                                doc,
                                annot,
                                fillOpaqueForAp,
                                strokePt,
                                FILL_DISPLAY_OPACITY,
                                lineW,
                                0.001);
            }
            if (ok) {
                zeroSquarePolygonBorderWidthForCustomAppearance(annot);
                rememberBauhubAreaOpaqueFillArgb(annot, rgbArgbFromColorPt(fillOpaqueForAp));
                setOpaqueInteriorColorAfterBauhubCustomAp(annot, rgbArgbFromColorPt(fillOpaqueForAp));
            } else {
                // Fallback (no custom AP): keep IC as the OPAQUE design colour for cross-platform
                // parity (web / iOS apply opacity="0.3" themselves and read IC at face value), and
                // lower CA to 0.3 so Android's default Square/Polygon render also looks translucent.
                try {
                    markup.setInteriorColor(argbToColorPt(rgbArgbFromColorPt(fillOpaqueForAp)), 3);
                    markup.setOpacity(FILL_DISPLAY_OPACITY);
                    annot.refreshAppearance();
                } catch (Exception ignored) {
                }
            }
        } catch (PDFNetException e) {
            AnalyticsHandlerAdapter.getInstance().sendException(e);
        }
    }

    /**
     * After {@link PDFDoc#refreshAnnotAppearances()} or FDF merge — rebuild translucent Bauhub area appearances.
     */
    public static void reapplyTranslucentAppearancesAfterGlobalRefresh(PDFDoc doc) {
        if (doc == null) {
            return;
        }
        try {
            int pageCount = doc.getPageCount();
            for (int p = 1; p <= pageCount; p++) {
                Page page = doc.getPage(p);
                int n = page.getNumAnnots();
                for (int i = 0; i < n; i++) {
                    Annot annot = page.getAnnot(i);
                    if (annot == null || !annot.isValid() || !annot.isMarkup()) {
                        continue;
                    }
                    reapplyBauhubAreaAppearanceForAnnot(doc, annot);
                }
            }
        } catch (PDFNetException e) {
            AnalyticsHandlerAdapter.getInstance().sendException(e);
        }
    }

    private static int rgbArgbFromColorPt(ColorPt c) {
        if (c == null) {
            return sFillArgb;
        }
        try {
            int r = (int) Math.round(c.get(0) * 255.0);
            int g = (int) Math.round(c.get(1) * 255.0);
            int b = (int) Math.round(c.get(2) * 255.0);
            r = Math.max(0, Math.min(255, r));
            g = Math.max(0, Math.min(255, g));
            b = Math.max(0, Math.min(255, b));
            return 0xFF000000 | (r << 16) | (g << 8) | b;
        } catch (Exception e) {
            return sFillArgb;
        }
    }

    private static int sqRgbDistanceArgb(int a, int b) {
        int dr = ((a >>> 16) & 0xFF) - ((b >>> 16) & 0xFF);
        int dg = ((a >>> 8) & 0xFF) - ((b >>> 8) & 0xFF);
        int db = (a & 0xFF) - (b & 0xFF);
        return dr * dr + dg * dg + db * db;
    }

    /**
     * {@link Markup#getInteriorColor()} usually stores the soft structure tint (see {@link #fillArgbBlendedTowardWhite}),
     * while {@link #trySetTranslucentAreaMarkupAppearance} multiplies that RGB by fill opacity in the form stream —
     * it needs the original opaque design color. When interior already matches opaque design, return it unchanged.
     */
    private static ColorPt opaqueFillForTranslucentCustomStream(ColorPt interiorFromMarkup) {
        if (interiorFromMarkup == null) {
            return argbToColorPt(sFillArgb);
        }
        int softArgb = rgbArgbFromColorPt(interiorFromMarkup);
        double t = FILL_DISPLAY_OPACITY;
        int sr = (softArgb >>> 16) & 0xFF;
        int sg = (softArgb >>> 8) & 0xFF;
        int sb = softArgb & 0xFF;
        int cr = (int) Math.round(255.0 + (sr - 255.0) / t);
        int cg = (int) Math.round(255.0 + (sg - 255.0) / t);
        int cb = (int) Math.round(255.0 + (sb - 255.0) / t);
        cr = Math.max(0, Math.min(255, cr));
        cg = Math.max(0, Math.min(255, cg));
        cb = Math.max(0, Math.min(255, cb));
        int recoveredArgb = 0xFF000000 | (cr << 16) | (cg << 8) | cb;
        ColorPt blendedCheck = fillArgbBlendedTowardWhite(recoveredArgb, t);
        int checkArgb = rgbArgbFromColorPt(blendedCheck);
        if (sqRgbDistanceArgb(softArgb, checkArgb) <= 200) {
            return argbToColorPt(recoveredArgb);
        }
        return interiorFromMarkup;
    }

    private static void zeroSquarePolygonBorderWidthForCustomAppearance(Annot annot) {
        try {
            if (annot == null || !annot.isValid()) {
                return;
            }
            int t = annot.getType();
            if (t != Annot.e_Square && t != Annot.e_Polygon) {
                return;
            }
            Annot.BorderStyle bs = annot.getBorderStyle();
            if (bs != null) {
                bs.setWidth(0);
                annot.setBorderStyle(bs);
            }
        } catch (Exception ignored) {
        }
    }

    private static boolean trySetTranslucentAreaMarkupAppearance(
            PDFDoc doc,
            Annot annot,
            ColorPt fillRgb,
            ColorPt strokeRgb,
            double fillOpacity,
            double lineWidth,
            double minSquareSide) {
        if (doc == null || annot == null || fillRgb == null || strokeRgb == null) {
            return false;
        }
        try {
            if (!annot.isValid()) {
                return false;
            }
        } catch (PDFNetException e) {
            return false;
        }
        if (fillOpacity < 0 || fillOpacity > 1) {
            return false;
        }
        final int type;
        try {
            type = annot.getType();
        } catch (Exception e) {
            return false;
        }
        if (type != Annot.e_Square && type != Annot.e_Polygon) {
            return false;
        }
        PolyLine polyLineForStroke = null;
        double sqLx = 0, sqLy = 0, sqW = 0, sqH = 0;
        try {
            if (type == Annot.e_Square) {
                Rect r = annot.getRect();
                double ax1 = r.getX1(), ay1 = r.getY1(), ax2 = r.getX2(), ay2 = r.getY2();
                sqLx = Math.min(ax1, ax2);
                sqLy = Math.min(ay1, ay2);
                sqW = Math.abs(ax2 - ax1);
                sqH = Math.abs(ay2 - ay1);
                if (sqW < minSquareSide || sqH < minSquareSide) {
                    return false;
                }
            } else {
                polyLineForStroke = new PolyLine(annot);
                if (!polyLineForStroke.isValid() || polyLineForStroke.getVertexCount() < 3) {
                    return false;
                }
            }
        } catch (Exception e) {
            return false;
        }

        ColorSpace rgb = null;
        ElementWriter writer = null;
        ElementBuilder builder = null;
        try {
            writer = new ElementWriter();
            builder = new ElementBuilder();
            rgb = ColorSpace.createDeviceRGB();
            writer.begin(doc.getSDFDoc(), true);
            if (type == Annot.e_Square) {
                if (fillOpacity > 0) {
                    Element fillEl = builder.createRect(sqLx, sqLy, sqW, sqH);
                    GState gsf = fillEl.getGState();
                    gsf.setFillColorSpace(rgb);
                    gsf.setFillColor(fillRgb);
                    gsf.setFillOpacity(fillOpacity);
                    gsf.setStrokeOpacity(1.0);
                    fillEl.setPathFill(true);
                    fillEl.setPathStroke(false);
                    writer.writePlacedElement(fillEl);
                }

                Element strokeEl = builder.createRect(sqLx, sqLy, sqW, sqH);
                GState gss = strokeEl.getGState();
                gss.setStrokeColorSpace(rgb);
                gss.setStrokeColor(strokeRgb);
                gss.setStrokeOpacity(1.0);
                gss.setFillOpacity(1.0);
                gss.setLineWidth(lineWidth);
                strokeEl.setPathFill(false);
                strokeEl.setPathStroke(true);
                writer.writePlacedElement(strokeEl);
            } else {
                PolyLine pl = polyLineForStroke;
                if (fillOpacity > 0) {
                    if (!appendClosedPolygonPath(builder, pl)) {
                        throw new IllegalStateException("bauhub polygon fill path");
                    }
                    Element fillPath = builder.pathEnd();
                    GState gsf = fillPath.getGState();
                    gsf.setFillColorSpace(rgb);
                    gsf.setFillColor(fillRgb);
                    gsf.setFillOpacity(fillOpacity);
                    gsf.setStrokeOpacity(1.0);
                    fillPath.setPathFill(true);
                    fillPath.setPathStroke(false);
                    writer.writePlacedElement(fillPath);
                }

                if (!appendClosedPolygonPath(builder, pl)) {
                    throw new IllegalStateException("bauhub polygon stroke path");
                }
                Element strokePath = builder.pathEnd();
                GState gss = strokePath.getGState();
                gss.setStrokeColorSpace(rgb);
                gss.setStrokeColor(strokeRgb);
                gss.setStrokeOpacity(1.0);
                gss.setFillOpacity(1.0);
                gss.setLineWidth(lineWidth);
                strokePath.setPathFill(false);
                strokePath.setPathStroke(true);
                writer.writePlacedElement(strokePath);
            }
            Obj form = writer.end();
            if (form == null || form.isNull() || !form.isStream()) {
                return false;
            }
            Rect bb = annot.getRect();
            double bx1 = Math.min(bb.getX1(), bb.getX2());
            double by1 = Math.min(bb.getY1(), bb.getY2());
            double bx2 = Math.max(bb.getX1(), bb.getX2());
            double by2 = Math.max(bb.getY1(), bb.getY2());
            form.putRect("BBox", bx1, by1, bx2, by2);
            annot.setAppearance(form, Annot.e_normal);
            return true;
        } catch (Exception e) {
            return false;
        } finally {
            if (writer != null) {
                try {
                    writer.destroy();
                } catch (Exception ignored) {
                }
            }
            if (builder != null) {
                try {
                    builder.destroy();
                } catch (Exception ignored) {
                }
            }
        }
    }

    private static boolean appendClosedPolygonPath(ElementBuilder builder, PolyLine pl) throws PDFNetException {
        int vc = pl.getVertexCount();
        if (vc < 3) {
            return false;
        }
        builder.pathBegin();
        Point p0 = pl.getVertex(0);
        builder.moveTo(p0.x, p0.y);
        for (int i = 1; i < vc; i++) {
            Point pi = pl.getVertex(i);
            builder.lineTo(pi.x, pi.y);
        }
        builder.closePath();
        return true;
    }

    private static ColorPt fillArgbBlendedTowardWhite(int argb, double t) {
        // Use >>> : opaque ARGB (0xFF......) is a negative int in Java; >> sign-extends and corrupts R/G.
        int r = (argb >>> 16) & 0xFF;
        int g = (argb >>> 8) & 0xFF;
        int b = argb & 0xFF;
        int r2 = (int) Math.round(255.0 + (r - 255.0) * t);
        int g2 = (int) Math.round(255.0 + (g - 255.0) * t);
        int b2 = (int) Math.round(255.0 + (b - 255.0) * t);
        r2 = Math.max(0, Math.min(255, r2));
        g2 = Math.max(0, Math.min(255, g2));
        b2 = Math.max(0, Math.min(255, b2));
        return Utils.color2ColorPt(0xFF000000 | (r2 << 16) | (g2 << 8) | b2);
    }

    /**
     * True for Bauhub square/polygon area markups (subjects Comment / Attachment / Task).
     * <p>Android redraws selected annotations in a way that can make the custom translucent fill
     * look empty; {@link com.pdftron.pdftronflutter.helpers.ViewerImpl} uses this to schedule a
     * translucency reapply after selection.
     */
    public static boolean isBauhubAreaShapeAnnot(@Nullable Annot annot) {
        if (annot == null) {
            return false;
        }
        try {
            if (!annot.isValid() || !annot.isMarkup()) {
                return false;
            }
            int type = annot.getType();
            if (type != Annot.e_Square && type != Annot.e_Polygon) {
                return false;
            }
            return isBauhubAreaSubject(new Markup(annot).getSubject());
        } catch (PDFNetException e) {
            return false;
        } catch (Exception e) {
            return false;
        }
    }

    private static boolean isBauhubAreaSubject(String subj) {
        return subj != null
                && ("Comment".equalsIgnoreCase(subj) || "Attachment".equalsIgnoreCase(subj) || "Task".equalsIgnoreCase(subj));
    }

    /**
     * Do not use {@link ToolManager#raiseAnnotationsModifiedEvent} here: it triggers a full
     * {@link Annot#refreshAppearance()} on Android and wipes the custom translucent area stream
     * (user sees default thick red stroke + empty fill). A view-only update is enough after styling.
     */
    private static void refreshAreaMarkupViewOnly(Tool tool, Annot annot) {
        try {
            PDFViewCtrl ctrl = BauhubToolsAccess.getPdfViewCtrl(tool);
            if (ctrl == null || annot == null || !annot.isValid()) {
                return;
            }
            PDFDoc doc = ctrl.getDoc();
            int pageNum = -1;
            if (doc != null) {
                try {
                    pageNum = BauhubAreaPinDecoration.resolvePageNumberForShapeAnnot(ctrl, doc, annot, tool);
                } catch (Exception ignored) {
                }
            }
            if (pageNum < 1) {
                try {
                    pageNum = ctrl.getCurrentPage();
                } catch (Exception ignored) {
                }
            }
            try {
                if (pageNum >= 1) {
                    ctrl.update(annot, pageNum);
                    BauhubAreaPinDecoration.refreshDecorativePinViewAfterShapeUpdate(ctrl, doc, pageNum, annot);
                    BauhubAreaPinDecoration.scheduleEnsureDecorativeAreaPinStampLastOnPage(
                            ctrl, doc, pageNum, annot, tool);
                } else {
                    ctrl.update();
                }
            } catch (Exception ignored) {
            }
        } catch (Exception ignored) {
        }
    }

    private static int findPageNumberForAnnot(PDFDoc doc, Annot target) throws PDFNetException {
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

    private static ColorPt argbToColorPt(int argb) {
        // Low 24 bits are sRGB; high byte forced opaque. Prefer Utils over `new ColorPt(r,g,b)` —
        // PDFNet 11.x ColorPt(double,double,double) throws checked PDFNetException.
        return Utils.color2ColorPt(0xFF000000 | (argb & 0xFFFFFF));
    }

    private static void ensureBauhubAnnotHasUniqueId(Tool tool, Annot annot) {
        try {
            PDFViewCtrl v = BauhubToolsAccess.getPdfViewCtrl(tool);
            ensureBauhubAnnotHasUniqueIdFromCtrl(v, annot);
        } catch (Exception ignored) {
        }
    }

    private static void ensureBauhubAnnotHasUniqueIdFromCtrl(@Nullable PDFViewCtrl v, Annot annot) {
        try {
            if (v == null) {
                return;
            }
            PDFDoc doc = v.getDoc();
            if (doc == null) {
                return;
            }
            String existing = null;
            try {
                if (annot.getUniqueID() != null) {
                    existing = annot.getUniqueID().getAsPDFText();
                }
            } catch (Exception ignored) {
            }
            if (existing != null && !existing.isEmpty()) {
                return;
            }
            annot.setUniqueID(UUID.randomUUID().toString());
        } catch (Exception ignored) {
        }
    }
}
