package com.pdftron.pdftronflutter.helpers;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.pdftron.pdf.Action;
import com.pdftron.pdf.ActionParameter;
import com.pdftron.pdf.Annot;
import com.pdftron.pdf.annots.Markup;
import com.pdftron.pdf.Field;
import com.pdftron.pdf.PDFDoc;
import com.pdftron.pdf.PDFViewCtrl;
import com.pdftron.pdftronflutter.bauhub.BauhubAreaPinDecoration;
import com.pdftron.pdftronflutter.bauhub.BauhubDecorativeAreaPinZoomSync;
import com.pdftron.pdftronflutter.bauhub.BauhubShapeMarkupStyle;
import com.pdftron.pdf.annots.Widget;
import com.pdftron.pdf.controls.PdfViewCtrlTabFragment2;
import com.pdftron.pdf.model.UserBookmarkItem;
import com.pdftron.pdf.tools.Pan;
import com.pdftron.pdf.tools.QuickMenu;
import com.pdftron.pdf.tools.QuickMenuItem;
import com.pdftron.pdf.tools.TextSelect;
import com.pdftron.pdf.tools.ToolManager;
import com.pdftron.pdf.utils.ActionUtils;
import com.pdftron.pdf.utils.AnnotUtils;
import com.pdftron.pdf.utils.ViewerUtils;
import com.pdftron.sdf.Obj;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;

import static com.pdftron.pdftronflutter.helpers.PluginUtils.BEHAVIOR_LINK_PRESS;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.KEY_ACTION;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.KEY_ANNOTATION_LIST;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.KEY_ANNOTATION_MENU_ITEM;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.KEY_DATA;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.KEY_LINK_BEHAVIOR_DATA;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.KEY_LONG_PRESS_MENU_ITEM;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.KEY_LONG_PRESS_TEXT;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.KEY_PAGE_NUMBER;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.KEY_PREVIOUS_PAGE_NUMBER;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.REFLOW_ORIENTATION_HORIZONTAL;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.REFLOW_ORIENTATION_VERTICAL;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.addBauhubRestrictedMarkupQuickMenuRemovals;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.checkQuickMenu;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.isBauhubRestrictedMarkupSubject;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.convStringToAnnotType;
import static com.pdftron.pdftronflutter.helpers.PluginUtils.getAnnotationsData;

public class ViewerImpl {

    private ViewerComponent mViewerComponent;
    private final Handler mMainHandler = new Handler(Looper.getMainLooper());
    private final Runnable mBauhubAreaReapplyRunnable =
            this::reapplyBauhubTranslucentAreaAppearancesAfterOtherAnnotChange;

    public ViewerImpl(@NonNull ViewerComponent component) {
        mViewerComponent = component;
    }

    public void addListeners(@NonNull ToolManager toolManager) {
        toolManager.addAnnotationModificationListener(mAnnotationModificationListener);
        toolManager.addAnnotationsSelectionListener(mAnnotationsSelectionListener);
        toolManager.addPdfDocModificationListener(mPdfDocModificationListener);
        // Selected annotations must look identical to unselected ones (the page-rendered AP).
        // PDFTron's "real-time annot edit" overlays an [AnnotView] (a fresh re-render based on
        // the annot's [IC] / [Color] / [Opacity] alone — our custom translucent {@code AP/N}
        // is ignored). For Bauhub squares, [AnnotDrawingView] then draws a fresh bitmap of the
        // AP which is acceptable; for Bauhub polygons it draws a path with {@code IC × CA},
        // collapsing the {@code fill 0.3 + stroke 1.0} appearance into a flat pastel that
        // users see as "all solid on click". Disabling real-time edit makes
        // {@code AnnotEdit.canAddAnnotView} return false: no overlay is created, the page-level
        // AP keeps rendering during selection, and only the selection box / drag handles
        // (drawn by [AnnotEdit.onDraw]) are added on top — exactly the iOS behaviour. The
        // trade-off is that resize/move shows the new size only at gesture-end (no in-flight
        // preview), which the user explicitly preferred over the colour change.
        toolManager.setRealTimeAnnotEdit(false);
    }

    public void addListeners(@NonNull PdfViewCtrlTabFragment2 pdfViewCtrlTabFragment) {
        pdfViewCtrlTabFragment.addQuickMenuListener(mQuickMenuListener);
    }

    public void addListeners(@NonNull PDFViewCtrl pdfViewCtrl) {
        pdfViewCtrl.addOnCanvasSizeChangeListener(mOnCanvasSizeChangedListener);
        pdfViewCtrl.addPageChangeListener(mPageChangedListener);
    }

    public void removeListeners(@NonNull ToolManager toolManager) {
        toolManager.removeAnnotationModificationListener(mAnnotationModificationListener);
        toolManager.removeAnnotationsSelectionListener(mAnnotationsSelectionListener);
        toolManager.removePdfDocModificationListener(mPdfDocModificationListener);
    }

    public void removeListeners(@NonNull PdfViewCtrlTabFragment2 pdfViewCtrlTabFragment) {
        pdfViewCtrlTabFragment.removeQuickMenuListener(mQuickMenuListener);
    }

    public void removeListeners(@NonNull PDFViewCtrl pdfViewCtrl) {
        pdfViewCtrl.removeOnCanvasSizeChangeListener(mOnCanvasSizeChangedListener);
        pdfViewCtrl.removePageChangeListener(mPageChangedListener);
    }

    public void setActionInterceptCallback() {
        ActionUtils.getInstance().setActionInterceptCallback(mActionInterceptCallback);
    }

    /**
     * Successful Bauhub custom area appearances clear PDF {@code IC} (fill is only in {@code AP}).
     * Adding another annotation can regenerate defaults and wipe {@code AP}. Rebuild all Bauhub area
     * appearances (same as post-merge refresh).
     *
     * <p>Also runs {@link BauhubAreaPinDecoration#decorateAllMatchingShapes} as a safety net — the
     * inline pin placement in {@link BauhubShapeMarkupStyle#apply} can silently fail for polygon
     * creates (the {@link com.pdftron.pdf.tools.AdvancedShapeCreate#commit} path releases its
     * write lock before the deferred {@code ctrl.post} stamp runnable fires, so
     * {@link com.pdftron.pdf.Stamper#stampImage} can drop without raising). Re-decorating every
     * Bauhub area/polygon on the doc here matches the XFDF import path that always places pins
     * correctly, and {@code alreadyHasPin}/{@code hasPinStampNearShapeCorner} keep this a no-op for
     * shapes that already got their pin from the tool-level stamp.
     */
    private void reapplyBauhubTranslucentAreaAppearancesAfterOtherAnnotChange() {
        PDFViewCtrl pdfViewCtrl = mViewerComponent.getPdfViewCtrl();
        if (pdfViewCtrl == null) {
            return;
        }
        boolean locked = false;
        try {
            PDFDoc doc = pdfViewCtrl.getDoc();
            if (doc == null || !pdfViewCtrl.docTryLock(2000)) {
                return;
            }
            locked = true;
            BauhubShapeMarkupStyle.reapplyTranslucentAppearancesAfterGlobalRefresh(doc);
            try {
                BauhubAreaPinDecoration.decorateAllMatchingShapes(pdfViewCtrl, doc);
            } catch (Exception e) {
                e.printStackTrace();
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            if (locked) {
                try {
                    pdfViewCtrl.docUnlock();
                } catch (Exception ignored) {
                }
            }
        }
        try {
            pdfViewCtrl.update(true);
        } catch (Exception ignored) {
        }
    }

    /** Coalesces rapid adds (e.g. batch) into one full-document Bauhub area AP rebuild. */
    private void scheduleBauhubTranslucentAreaReapplyAfterOtherAnnotChange() {
        mMainHandler.removeCallbacks(mBauhubAreaReapplyRunnable);
        mMainHandler.postDelayed(mBauhubAreaReapplyRunnable, 75);
    }

    /**
     * Returns true if any annotation in {@code map} is a Bauhub area markup (square / polygon with
     * a {@code Comment} / {@code Attachment} / {@code Task} subject). Used to skip the (somewhat
     * heavy) global reapply on modifications that touch only non-Bauhub annotations (e.g. a sticky
     * note dragged across the page does not need our translucent AP rebuilt).
     */
    private static boolean containsBauhubAreaAnnotation(@Nullable Map<Annot, Integer> map) {
        if (map == null || map.isEmpty()) {
            return false;
        }
        for (Annot annot : map.keySet()) {
            try {
                if (annot == null || !annot.isValid() || !annot.isMarkup()) {
                    continue;
                }
                int t = annot.getType();
                if (t != Annot.e_Square && t != Annot.e_Polygon) {
                    continue;
                }
                String subj = new Markup(annot).getSubject();
                if (subj == null) {
                    continue;
                }
                if ("Comment".equalsIgnoreCase(subj)
                        || "Attachment".equalsIgnoreCase(subj)
                        || "Task".equalsIgnoreCase(subj)) {
                    return true;
                }
            } catch (Exception ignored) {
            }
        }
        return false;
    }


    /**
     * Moves each modified Bauhub area shape's linked decorative pin to the shape's new top-left
     * corner so the pin follows a drag/resize instead of being "left behind" until the document is
     * reopened. Runs synchronously under a short write lock; the debounced translucent-AP reapply
     * that follows re-decorates idempotently (the pin is now near the new corner, so it dedups out).
     */
    private void repositionDecorativePinsForModifiedAreas(@Nullable Map<Annot, Integer> map) {
        if (map == null || map.isEmpty()) {
            return;
        }
        PDFViewCtrl pdfViewCtrl = mViewerComponent.getPdfViewCtrl();
        if (pdfViewCtrl == null) {
            return;
        }
        boolean locked = false;
        try {
            PDFDoc doc = pdfViewCtrl.getDoc();
            if (doc == null || !pdfViewCtrl.docTryLock(2000)) {
                return;
            }
            locked = true;
            for (Map.Entry<Annot, Integer> e : map.entrySet()) {
                Annot a = e.getKey();
                Integer p = e.getValue();
                if (a == null || !a.isValid() || !BauhubShapeMarkupStyle.isBauhubAreaShapeAnnot(a)) {
                    continue;
                }
                int pageNum = p != null ? p : -1;
                BauhubAreaPinDecoration.repositionDecorativePinForParentShape(pdfViewCtrl, doc, pageNum, a);
            }
        } catch (Exception ex) {
            ex.printStackTrace();
        } finally {
            if (locked) {
                try {
                    pdfViewCtrl.docUnlock();
                } catch (Exception ignored) {
                }
            }
        }
    }

    private ToolManager.AnnotationModificationListener mAnnotationModificationListener = new ToolManager.AnnotationModificationListener() {
        @Override
        public void onAnnotationsAdded(Map<Annot, Integer> map) {
            scheduleBauhubTranslucentAreaReapplyAfterOtherAnnotChange();
            PluginUtils.emitAnnotationChangedEvent(PluginUtils.KEY_ACTION_ADD, map, mViewerComponent);

            PluginUtils.emitExportAnnotationCommandEvent(PluginUtils.KEY_ACTION_ADD, map, mViewerComponent);
        }

        @Override
        public void onAnnotationsPreModify(Map<Annot, Integer> map) {
        }

        @Override
        public void onAnnotationsModified(Map<Annot, Integer> map, Bundle bundle) {
            // PDFTron rebuilds the appearance stream after a resize/move (AnnotEdit.onUp →
            // updateAnnot → refreshAppearance). The default rebuild ignores our custom translucent
            // {@code AP/N} (fill 0.3, stroke 1.0) and falls back to {@code IC × CA} at the default
            // opacity, which collapses the area into a flat solid colour. Reapply the Bauhub
            // appearance for every modified Bauhub area annot so resizing/moving keeps the
            // translucent fill + opaque outline. The 75 ms debounce inside
            // [scheduleBauhubTranslucentAreaReapplyAfterOtherAnnotChange] coalesces drag-end +
            // any subsequent modify events; the visual change is imperceptible to the user.
            if (containsBauhubAreaAnnotation(map)) {
                repositionDecorativePinsForModifiedAreas(map);
                scheduleBauhubTranslucentAreaReapplyAfterOtherAnnotChange();
            }

            PluginUtils.emitAnnotationChangedEvent(PluginUtils.KEY_ACTION_MODIFY, map, mViewerComponent);

            PluginUtils.emitExportAnnotationCommandEvent(PluginUtils.KEY_ACTION_MODIFY, map, mViewerComponent);

            JSONArray fieldsArray = new JSONArray();

            for (Annot annot : map.keySet()) {
                try {
                    if (annot != null && annot.isValid() && annot.getType() == Annot.e_Widget) {

                        String fieldName = null, fieldValue = null;

                        Widget widget = new Widget(annot);
                        Field field = widget.getField();
                        if (field != null) {
                            fieldName = field.getName();
                            fieldValue = field.getValueAsString();
                        }

                        if (fieldName != null && fieldValue != null) {
                            JSONObject fieldObject = new JSONObject();
                            fieldObject.put(PluginUtils.KEY_FIELD_NAME, fieldName);
                            fieldObject.put(PluginUtils.KEY_FIELD_VALUE, fieldValue);
                            fieldsArray.put(fieldObject);
                        }
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }

            EventChannel.EventSink eventSink = mViewerComponent.getFormFieldValueChangedEventEmitter();
            if (eventSink != null) {
                eventSink.success(fieldsArray.toString());
            }
        }

        @Override
        public void onAnnotationsPreRemove(Map<Annot, Integer> map) {
            PDFViewCtrl pdfViewCtrl = mViewerComponent.getPdfViewCtrl();
            if (pdfViewCtrl != null && map != null && !map.isEmpty()) {
                boolean locked = false;
                try {
                    PDFDoc doc = pdfViewCtrl.getDoc();
                    if (doc != null && pdfViewCtrl.docTryLock(2000)) {
                        locked = true;
                        for (Map.Entry<Annot, Integer> e : map.entrySet()) {
                            Annot a = e.getKey();
                            Integer p = e.getValue();
                            if (a != null && a.isValid() && p != null && p > 0) {
                                BauhubAreaPinDecoration.removeDecorativePinsForParentShapeRemoval(
                                        pdfViewCtrl, doc, a, p);
                            }
                        }
                    }
                } catch (Exception ex) {
                    ex.printStackTrace();
                } finally {
                    if (locked) {
                        try {
                            pdfViewCtrl.docUnlock();
                        } catch (Exception ignored) {
                        }
                    }
                }
            }
            PluginUtils.emitAnnotationChangedEvent(PluginUtils.KEY_ACTION_DELETE, map, mViewerComponent);

            PluginUtils.emitExportAnnotationCommandEvent(PluginUtils.KEY_ACTION_DELETE, map, mViewerComponent);
        }

        @Override
        public void onAnnotationsRemoved(Map<Annot, Integer> map) {

        }

        @Override
        public void onAnnotationsRemovedOnPage(int i) {

        }

        @Override
        public void annotationsCouldNotBeAdded(String s) {

        }
    };

    private ToolManager.AnnotationsSelectionListener mAnnotationsSelectionListener = new ToolManager.AnnotationsSelectionListener() {
        @Override
        public void onAnnotationsSelectionChanged(HashMap<Annot, Integer> hashMap) {
            PluginUtils.emitAnnotationsSelectedEvent(hashMap, mViewerComponent);
        }
    };

    private ToolManager.PdfDocModificationListener mPdfDocModificationListener = new ToolManager.PdfDocModificationListener() {

        @Override
        public void onBookmarkModified(@NonNull List<UserBookmarkItem> bookmarkItems) {
            String bookmarkJson = null;
            try {
                bookmarkJson = PluginUtils.generateBookmarkJson(mViewerComponent);
            } catch (JSONException e) {
                e.printStackTrace();
            }

            EventChannel.EventSink eventSink = mViewerComponent.getExportBookmarkEventEmitter();
            if (eventSink != null) {
                eventSink.success(bookmarkJson);
            }
        }

        @Override
        public void onPagesCropped() {

        }

        @Override
        public void onPagesAdded(List<Integer> list) {

        }

        @Override
        public void onPagesDeleted(List<Integer> list) {

        }

        @Override
        public void onPagesRotated(List<Integer> list) {

        }

        @Override
        public void onPageMoved(int from, int to) {
            EventChannel.EventSink eventSink = mViewerComponent.getPageMovedEventEmitter();
            if (eventSink != null) {
                JSONObject resultObject = new JSONObject();
                try {
                    resultObject.put(KEY_PREVIOUS_PAGE_NUMBER, from);
                    resultObject.put(KEY_PAGE_NUMBER, to);
                } catch (JSONException e) {
                    e.printStackTrace();
                }

                eventSink.success(resultObject.toString());
            }
        }

        @Override
        public void onPagesMoved(List<Integer> pagesMoved, int to, int currentPage) {

        }

        @Override
        public void onPageLabelsChanged() {

        }

        @Override
        public void onAllAnnotationsRemoved() {

        }

        @Override
        public void onAnnotationAction() {

        }
    };

    private ActionUtils.ActionInterceptCallback mActionInterceptCallback = new ActionUtils.ActionInterceptCallback() {
        @Override
        public boolean onInterceptExecuteAction(ActionParameter actionParameter, PDFViewCtrl pdfViewCtrl) {
            ArrayList<String> actionOverrideItems = mViewerComponent.getActionOverrideItems();
            if (actionOverrideItems == null || !actionOverrideItems.contains(BEHAVIOR_LINK_PRESS)) {
                return false;
            }

            String url = null;
            boolean shouldUnlockRead = false;
            try {
                pdfViewCtrl.docLockRead();
                shouldUnlockRead = true;

                Action action = actionParameter.getAction();
                int action_type = action.getType();
                if (action_type == Action.e_URI) {
                    Obj o = action.getSDFObj();
                    o = o.findObj("URI");
                    if (o != null) {
                        url = o.getAsPDFText();
                    }
                }
            } catch (Exception ex) {
                ex.printStackTrace();
            } finally {
                if (shouldUnlockRead) {
                    pdfViewCtrl.docUnlockRead();
                }
            }
            if (url != null) {
                try {
                    JSONObject behaviorObject = new JSONObject();

                    behaviorObject.put(KEY_ACTION, BEHAVIOR_LINK_PRESS);

                    JSONObject dataObject = new JSONObject();
                    dataObject.put(KEY_LINK_BEHAVIOR_DATA, url);

                    behaviorObject.put(KEY_DATA, dataObject);

                    EventChannel.EventSink eventSink = mViewerComponent.getBehaviorActivatedEventEmitter();
                    if (eventSink != null) {
                        eventSink.success(behaviorObject.toString());
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
                return true;
            }
            return false;
        }
    };

    private ToolManager.QuickMenuListener mQuickMenuListener = new ToolManager.QuickMenuListener() {
        @Override
        public boolean onQuickMenuClicked(QuickMenuItem quickMenuItem) {
            String menuStr = PluginUtils.convQuickMenuIdToString(quickMenuItem.getItemId());

            // check if this is an override menu
            boolean result = false;

            if (mViewerComponent.getPdfViewCtrl() != null && mViewerComponent.getToolManager() != null) {

                // If annotations are selected - annotationMenu; Or: - longPressMenu
                if (PluginUtils.hasAnnotationsSelected(mViewerComponent)) {
                    if (mViewerComponent.getAnnotationMenuOverrideItems() != null) {
                        result = mViewerComponent.getAnnotationMenuOverrideItems().contains(menuStr);
                    }

                    try {
                        JSONObject annotationMenuObject = new JSONObject();
                        annotationMenuObject.put(KEY_ANNOTATION_MENU_ITEM, menuStr);
                        annotationMenuObject.put(KEY_ANNOTATION_LIST, getAnnotationsData(mViewerComponent));

                        EventChannel.EventSink eventSink = mViewerComponent.getAnnotationMenuPressedEventEmitter();
                        if (eventSink != null) {
                            eventSink.success(annotationMenuObject.toString());
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                } else {
                    if (mViewerComponent.getLongPressMenuOverrideItems() != null) {
                        result = mViewerComponent.getLongPressMenuOverrideItems().contains(menuStr);
                    }

                    try {
                        JSONObject longPressMenuObject = new JSONObject();
                        longPressMenuObject.put(KEY_LONG_PRESS_MENU_ITEM, menuStr);
                        longPressMenuObject.put(KEY_LONG_PRESS_TEXT, ViewerUtils.getSelectedString(mViewerComponent.getPdfViewCtrl()));

                        EventChannel.EventSink eventSink = mViewerComponent.getLongPressMenuPressedEventEmitter();
                        if (eventSink != null) {
                            eventSink.success(longPressMenuObject.toString());
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            }

            return result;
        }

        @Override
        public boolean onShowQuickMenu(QuickMenu quickMenu, @Nullable Annot annot) {
            if (mViewerComponent.getHideAnnotationMenuTools() != null && annot != null && mViewerComponent.getPdfViewCtrl() != null) {
                for (String tool : mViewerComponent.getHideAnnotationMenuTools()) {
                    int type = convStringToAnnotType(tool);
                    boolean shouldUnlockRead = false;
                    try {
                        mViewerComponent.getPdfViewCtrl().docLockRead();
                        shouldUnlockRead = true;

                        int annotType = AnnotUtils.getAnnotType(annot);
                        if (annotType == type) {
                            mViewerComponent.getPdfViewCtrl().docUnlockRead();
                            return true;
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    } finally {
                        if (shouldUnlockRead) {
                            mViewerComponent.getPdfViewCtrl().docUnlockRead();
                        }
                    }
                }
            }

            // remove unwanted items
            ToolManager.Tool currentTool = mViewerComponent.getToolManager() != null ? mViewerComponent.getToolManager().getTool() : null;
            if (mViewerComponent.getAnnotationMenuItems() != null && !(currentTool instanceof Pan) && !(currentTool instanceof TextSelect)) {
                List<QuickMenuItem> removeList = new ArrayList<>();
                checkQuickMenu(quickMenu.getFirstRowMenuItems(), mViewerComponent.getAnnotationMenuItems(), removeList);
                checkQuickMenu(quickMenu.getSecondRowMenuItems(), mViewerComponent.getAnnotationMenuItems(), removeList);
                checkQuickMenu(quickMenu.getOverflowMenuItems(), mViewerComponent.getAnnotationMenuItems(), removeList);
                quickMenu.removeMenuEntries(removeList);

                if (quickMenu.getFirstRowMenuItems().size() == 0) {
                    quickMenu.setDividerVisibility(View.GONE);
                }
            }
            if (mViewerComponent.getLongPressMenuItems() != null && (currentTool instanceof Pan || currentTool instanceof TextSelect)) {
                List<QuickMenuItem> removeList = new ArrayList<>();
                checkQuickMenu(quickMenu.getFirstRowMenuItems(), mViewerComponent.getLongPressMenuItems(), removeList);
                checkQuickMenu(quickMenu.getSecondRowMenuItems(), mViewerComponent.getLongPressMenuItems(), removeList);
                checkQuickMenu(quickMenu.getOverflowMenuItems(), mViewerComponent.getLongPressMenuItems(), removeList);
                quickMenu.removeMenuEntries(removeList);

                if (quickMenu.getFirstRowMenuItems().size() == 0) {
                    quickMenu.setDividerVisibility(View.GONE);
                }
            }

            if (annot != null && mViewerComponent.getPdfViewCtrl() != null) {
                boolean stripBauhubMenus = false;
                boolean unlockRead = false;
                try {
                    mViewerComponent.getPdfViewCtrl().docLockRead();
                    unlockRead = true;
                    if (annot.isMarkup()) {
                        String subject = new Markup(annot).getSubject();
                        stripBauhubMenus = isBauhubRestrictedMarkupSubject(subject);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                } finally {
                    if (unlockRead) {
                        mViewerComponent.getPdfViewCtrl().docUnlockRead();
                    }
                }
                if (stripBauhubMenus) {
                    List<QuickMenuItem> stripList = new ArrayList<>();
                    addBauhubRestrictedMarkupQuickMenuRemovals(quickMenu, stripList);
                    quickMenu.removeMenuEntries(stripList);
                    if (quickMenu.getFirstRowMenuItems().size() == 0) {
                        quickMenu.setDividerVisibility(View.GONE);
                    }
                }
            }
            return false;
        }

        @Override
        public void onQuickMenuShown() {

        }

        @Override
        public void onQuickMenuDismissed() {

        }
    };

    private PDFViewCtrl.OnCanvasSizeChangeListener mOnCanvasSizeChangedListener = new PDFViewCtrl.OnCanvasSizeChangeListener() {
        @Override
        public void onCanvasSizeChanged() {
            PDFViewCtrl pdfViewCtrl = mViewerComponent.getPdfViewCtrl();
            if (pdfViewCtrl != null) {
                BauhubDecorativeAreaPinZoomSync.requestSync(pdfViewCtrl);
            }
            EventChannel.EventSink eventSink = mViewerComponent.getZoomChangedEventEmitter();
            if (eventSink != null && pdfViewCtrl != null) {
                eventSink.success(pdfViewCtrl.getZoom());
            }
        }
    };

    private PDFViewCtrl.PageChangeListener mPageChangedListener = new PDFViewCtrl.PageChangeListener() {
        @Override
        public void onPageChange(int old_page, int cur_page, PDFViewCtrl.PageChangeState pageChangeState) {
            EventChannel.EventSink eventSink = mViewerComponent.getPageChangedEventEmitter();
            if (eventSink != null && (old_page != cur_page || pageChangeState == PDFViewCtrl.PageChangeState.END)) {
                JSONObject resultObject = new JSONObject();
                try {
                    resultObject.put(KEY_PREVIOUS_PAGE_NUMBER, old_page);
                    resultObject.put(KEY_PAGE_NUMBER, cur_page);
                } catch (JSONException e) {
                    e.printStackTrace();
                }

                eventSink.success(resultObject.toString());
            }
        }
    };
}
