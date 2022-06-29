part of pdftron;

typedef void DocumentViewCreatedCallback(DocumentViewController controller);

class DocumentView extends StatefulWidget {
  const DocumentView({Key? key, required this.onCreated}) : super(key: key);

  final DocumentViewCreatedCallback onCreated;

  @override
  State<StatefulWidget> createState() => _DocumentViewState();
}

class _DocumentViewState extends State<DocumentView> {
  @override
  Widget build(BuildContext context) {
  final String viewType = 'pdftron_flutter/documentview';

    if (Platform.isAndroid) {
      return PlatformViewLink(
          viewType: viewType,
          surfaceFactory: (BuildContext context, PlatformViewController controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController, 
              hitTestBehavior: PlatformViewHitTestBehavior.opaque, 
              gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>[].toSet());
          }, 
          onCreatePlatformView: (PlatformViewCreationParams params) {
            return PlatformViewsService.initSurfaceAndroidView(
              id: params.id,
              viewType: viewType,
              layoutDirection: TextDirection.ltr,
            )
              ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
              ..addOnPlatformViewCreatedListener(_onPlatformViewCreated)
              ..create();
          });
    } else if (Platform.isIOS) {
      return UiKitView(
        viewType: viewType,
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return Text('coming soon');
  }

  void _onPlatformViewCreated(int id) {
    widget.onCreated(new DocumentViewController._(id));
  }
}

class DocumentViewController {
  DocumentViewController._(int id)
      : _channel = new MethodChannel('pdftron_flutter/documentview_$id');

  final MethodChannel _channel;

  Future<Rect?> setCustomDataForAnnotation(Annot annotation, List<String> fieldNames) async {
    return _channel.invokeMethod(Functions.setCustomDataForAnnotation,
        <String, dynamic>{Parameters.annotation: jsonEncode(annotation), Parameters.fieldNames: fieldNames});
  }

  Future<bool> isBauhubToolMode() async {
    String result = await _channel.invokeMethod(Functions.isBauhubToolMode);
    print(result);
    return result == 'true';
  }

  Future<void> openDocument(String document, {String? password, Config? config}) {
    return _channel.invokeMethod(Functions.openDocument, <String, dynamic>{
      Parameters.document: document,
      Parameters.password: password,
      Parameters.config: jsonEncode(config)
    });
  }

  Future<void> importAnnotations(String xfdf) {
    return _channel.invokeMethod(
        Functions.importAnnotations, <String, dynamic>{Parameters.xfdf: xfdf});
  }

  Future<String?> exportAnnotations(List<Annot>? annotationList) async {
    if (annotationList == null) {
      return _channel.invokeMethod(Functions.exportAnnotations);
    } else {
      return _channel.invokeMethod(
          Functions.exportAnnotations, <String, dynamic>{
        Parameters.annotations: jsonEncode(annotationList)
      });
    }
  }

  Future<void> flattenAnnotations(bool formsOnly) {
    return _channel.invokeMethod(Functions.flattenAnnotations,
        <String, dynamic>{Parameters.formsOnly: formsOnly});
  }

  Future<void> deleteAnnotations(List<Annot> annotationList) {
    return _channel.invokeMethod(Functions.deleteAnnotations,
        <String, dynamic>{Parameters.annotations: jsonEncode(annotationList)});
  }

  Future<void> selectAnnotation(Annot annotation) {
    return _channel.invokeMethod(Functions.selectAnnotation,
        <String, dynamic>{Parameters.annotation: jsonEncode(annotation)});
  }

  Future<bool?> hideAnnotation(Annot annotation) {
    return _channel.invokeMethod(Functions.hideAnnotation,
        <String, dynamic>{Parameters.annotation: jsonEncode(annotation)});
  }

  Future<bool?> hideAllAnnotations(int pageNumber) {
    return _channel.invokeMethod(Functions.hideAllAnnotations,
        <String, dynamic>{Parameters.pageNumber: pageNumber});
  }

  Future<bool?> showAnnotation(Annot annotation) {
    return _channel.invokeMethod(Functions.showAnnotation,
        <String, dynamic>{Parameters.annotation: jsonEncode(annotation)});
  }

  Future<void> setFlagsForAnnotations(
      List<AnnotWithFlag> annotationWithFlagsList) {
    return _channel.invokeMethod(
        Functions.setFlagsForAnnotations, <String, dynamic>{
      Parameters.annotationsWithFlags: jsonEncode(annotationWithFlagsList)
    });
  }

  Future<void> setPropertiesForAnnotation(
      Annot annotation, AnnotProperty property) {
    return _channel
        .invokeMethod(Functions.setPropertiesForAnnotation, <String, dynamic>{
      Parameters.annotation: jsonEncode(annotation),
      Parameters.annotationProperties: jsonEncode(property),
    });
  }

  Future<void> groupAnnotations(
      Annot primaryAnnotation, List<Annot> subAnnotations) {
    return _channel
        .invokeMethod(Functions.groupAnnotations, <String, dynamic>{
      Parameters.annotation: jsonEncode(primaryAnnotation),
      Parameters.annotations: jsonEncode(subAnnotations),
    });
  }

  Future<void> ungroupAnnotations(
      List<Annot> annotations) {
    return _channel
        .invokeMethod(Functions.ungroupAnnotations, <String, dynamic>{
      Parameters.annotations: jsonEncode(annotations),
    });
  }

  Future<void> importAnnotationCommand(String xfdfCommand) {
    return _channel.invokeMethod(Functions.importAnnotationCommand,
        <String, dynamic>{Parameters.xfdfCommand: xfdfCommand});
  }

  Future<void> importBookmarkJson(String bookmarkJson) {
    return _channel.invokeMethod(Functions.importBookmarkJson,
        <String, dynamic>{Parameters.bookmarkJson: bookmarkJson});
  }

  Future<void> addBookmark(String title, int pageNumber) {
    return _channel
        .invokeMethod(Functions.addBookmark, <String, dynamic>{
      Parameters.title: title,
      Parameters.pageNumber: pageNumber
    });
  }

  Future<String?> saveDocument() {
    return _channel.invokeMethod(Functions.saveDocument);
  }

  Future<bool?> commitTool() {
    return _channel.invokeMethod(Functions.commitTool);
  }

  Future<int?> getPageCount() {
    return _channel.invokeMethod(Functions.getPageCount);
  }

  Future<bool?> handleBackButton() {
    return _channel.invokeMethod(Functions.handleBackButton);
  }

  Future<void> undo() {
    return _channel.invokeMethod(Functions.undo);
  }
  
  Future<void> redo() {
    return _channel.invokeMethod(Functions.redo);
  }

  Future<bool?> canUndo() {
    return _channel.invokeMethod(Functions.canUndo);
  }
  
  Future<bool?> canRedo() {
    return _channel.invokeMethod(Functions.canRedo);
  }

  Future<Rect> getPageCropBox(int pageNumber) async {
    String cropBoxString = await _channel.invokeMethod(Functions.getPageCropBox,
        <String, dynamic>{Parameters.pageNumber: pageNumber});
    return Rect.fromJson(jsonDecode(cropBoxString));
  }

  Future<int> getPageRotation(int pageNumber) async {
    int pageRotation = await _channel.invokeMethod(Functions.getPageRotation,
        <String, dynamic>{Parameters.pageNumber: pageNumber});
    return pageRotation;
  }

  Future<void> rotateClockwise() {
    return _channel.invokeMethod(Functions.rotateClockwise);
  }

  Future<void> rotateCounterClockwise() {
    return _channel.invokeMethod(Functions.rotateCounterClockwise);
  }

  Future<bool?> setCurrentPage(int pageNumber) {
    return _channel.invokeMethod(Functions.setCurrentPage,
        <String, dynamic>{Parameters.pageNumber: pageNumber});
  }

  Future<String?> getDocumentPath() {
    return _channel.invokeMethod(Functions.getDocumentPath);
  }

  Future<void> setToolMode(String toolMode) {
    return _channel.invokeMethod(Functions.setToolMode,
        <String, dynamic>{Parameters.toolMode: toolMode});
  }

  Future<void> setFlagForFields(
      List<String> fieldNames, int flag, bool flagValue) {
    return _channel.invokeMethod(Functions.setFlagForFields, <String, dynamic>{
      Parameters.fieldNames: fieldNames,
      Parameters.flag: flag,
      Parameters.flagValue: flagValue
    });
  }

  Future<void> setValuesForFields(List<Field> fields) {
    return _channel.invokeMethod(Functions.setValuesForFields,
        <String, dynamic>{Parameters.fields: jsonEncode(fields)});
  }

  Future<void> setLeadingNavButtonIcon(String path) {
    return _channel.invokeMethod(Functions.setLeadingNavButtonIcon,
        <String, dynamic>{Parameters.leadingNavButtonIcon: path});
  }

  Future<void> closeAllTabs() {
    return _channel.invokeMethod(Functions.closeAllTabs);
  }

  Future<void> deleteAllAnnotations() {
    return _channel.invokeMethod(Functions.deleteAllAnnotations);
  }

  Future<String?> exportAsImage(int pageNumber, int dpi, String exportFormat) {
    return _channel.invokeMethod(Functions.exportAsImage, <String, dynamic>{
      Parameters.pageNumber: pageNumber,
      Parameters.dpi: dpi,
      Parameters.exportFormat: exportFormat
    });
  }

  /// Export a PDF page to an image format defined in ExportFormat.
  /// The page is taken from the PDF at the given filepath.
  Future<String?> exportAsImageFromFilePath(
      int? pageNumber, int? dpi, String? exportFormat, String? filePath) {
    return _channel
        .invokeMethod(Functions.exportAsImageFromFilePath, <String, dynamic>{
      Parameters.pageNumber: pageNumber,
      Parameters.dpi: dpi,
      Parameters.exportFormat: exportFormat,
      Parameters.path: filePath
    });
  }

  /// Displays the annotation tab of the existing list container.
  ///
  /// If this tab has been disabled, the method does nothing.
  Future<void> openAnnotationList() {
    return _channel.invokeMethod(Functions.openAnnotationList);
  }

  Future<void> openBookmarkList() {
    return _channel.invokeMethod(Functions.openBookmarkList);
  }

  Future<void> openOutlineList() {
    return _channel.invokeMethod(Functions.openOutlineList);
  }

  Future<void> openLayersList() {
    return _channel.invokeMethod(Functions.openLayersList);
  }

  Future<void> openThumbnailsView() {
    return _channel.invokeMethod(Functions.openThumbnailsView);
  }
  
  Future<void> openRotateDialog() {
    return _channel.invokeMethod(Functions.openRotateDialog);
  }

  Future<void> openAddPagesView(Map<String, double> sourceRect) {
    return _channel.invokeMethod(Functions.openAddPagesView,
        <String, dynamic>{Parameters.sourceRect: sourceRect});
  }

  Future<void> openViewSettings(Map<String, double> sourceRect) {
    return _channel.invokeMethod(Functions.openViewSettings,
        <String, dynamic>{Parameters.sourceRect: sourceRect});
  }

  Future<void> openCrop() {
    return _channel.invokeMethod(Functions.openCrop);
  }

  Future<void> openManualCrop() {
    return _channel.invokeMethod(Functions.openManualCrop);
  }

  Future<void> openSearch() {
    return _channel.invokeMethod(Functions.openSearch);
  }

  Future<void> openTabSwitcher() {
    return _channel.invokeMethod(Functions.openTabSwitcher);
  }
  
  Future<void> openGoToPageView() {
    return _channel.invokeMethod(Functions.openGoToPageView);
  }

  Future<void> openNavigationLists() {
    return _channel.invokeMethod(Functions.openNavigationLists);
  }

  Future<bool?> gotoPreviousPage() {
    return _channel.invokeMethod(Functions.gotoPreviousPage);
  }

  Future<bool?> gotoNextPage() {
    return _channel.invokeMethod(Functions.gotoNextPage);
  }

  Future<bool?> gotoFirstPage() {
    return _channel.invokeMethod(Functions.gotoFirstPage);
  }

  Future<bool?> gotoLastPage() {
    return _channel.invokeMethod(Functions.gotoLastPage);
  }

  Future<int?> getCurrentPage() {
    return _channel.invokeMethod(Functions.getCurrentPage);
  }

  /// Sets the zoom scale in the current document viewer with a zoom center.
  ///
  /// zoom: the zoom ratio to be set
  /// x: the x-coordinate of the zoom center
  /// y: the y-coordinate of the zoom center
  Future<void> zoomWithCenter(double zoom, int x, int y) {
    return _channel.invokeMethod(Functions.zoomWithCenter,
        <String, dynamic>{"zoom": zoom, "x": x, "y": y});
  }

  /// Zoom the viewer to a specific rectangular area in a page.
  ///
  /// pageNumber: the page number of the zooming area (1-indexed)
  /// rect: The rectangular area with keys x1 (left), y1(bottom), y1(right), y2(top). Coordinates are in double
  Future<void> zoomToRect(int pageNumber, Map<String, double> rect) {
    return _channel.invokeMethod(Functions.zoomToRect, <String, dynamic>{
      Parameters.pageNumber: pageNumber,
      "x1": rect["x1"],
      "y1": rect["y1"],
      "x2": rect["x2"],
      "y2": rect["y2"]
    });
  }
  /// Returns the current zoom scale of current document viewer.
  ///
  /// Returns a Promise.
  Future<double?> getZoom() {
    return _channel.invokeMethod(Functions.getZoom);
  }

  /// Sets the minimum and maximum zoom bounds of current viewer.
  Future<void> setZoomLimits(String mode, double minimum, double maximum) {
    return _channel.invokeMethod(Functions.setZoomLimits, <String, dynamic>{
      'zoomLimitMode': mode,
      'minimum': minimum,
      'maximum': maximum,
    });
  }

  /// Gets a list of absolute file paths to PDFs containing the saved signatures.
  ///
  /// Returns a promise
  Future<List<String>?> getSavedSignatures() {
    return _channel.invokeMethod(Functions.getSavedSignatures);
  }

  /// Retrieves the absolute file path to the folder containing the saved signature PDFs.
  /// For Android, to get the folder containing the saved signature JPGs, use getSavedSignatureJpgFolder.
  ///
  /// Returns a Promise.
  Future<String?> getSavedSignatureFolder() {
    return _channel.invokeMethod(Functions.getSavedSignatureFolder);
  }

  /// Retrieves the absolute file path to the folder containing the saved signature JPGs. Android only.
  /// To get the folder containing the saved signature PDFs, use getSavedSignatureFolder.
  ///
  /// Returns a Promise.
  Future<String?> getSavedSignatureJpgFolder() {
    return _channel.invokeMethod(Functions.getSavedSignatureJpgFolder);
  }
}
