import '../pdftron_flutter.dart';

class Config {
  var _disabledElements;
  var _disabledTools;
  var _multiTabEnabled;
  var _customHeaders;
  var _fitMode;
  var _layoutMode;
  var _tabletLayoutEnabled;
  var _initialPageNumber;
  var _isBase64String;
  var _base64FileExtension;
  var _hideThumbnailFilterModes;
  var _longPressMenuEnabled;
  var _longPressMenuItems;
  var _overrideLongPressMenuBehavior;
  var _hideAnnotationMenu;
  var _annotationMenuItems;
  var _overrideAnnotationMenuBehavior;
  var _excludedAnnotationListTypes;
  var _exportPath;
  var _openUrlPath;
  var _openSavedCopyInNewTab;
  var _maxTabCount;
  var _autoSaveEnabled;
  var _showDocumentSavedToast;
  var _pageChangeOnTap;
  var _showSavedSignatures;
  var _signaturePhotoPickerEnabled;
  var _signatureTypingEnabled;
  var _signatureDrawingEnabled;
  var _useStylusAsPen;
  var _signSignatureFieldWithStamps;
  var _signatureColors;
  var _selectAnnotationAfterCreation;
  var _pageIndicatorEnabled;
  var _showQuickNavigationButton;
  var _followSystemDarkMode;
  var _downloadDialogEnabled;
  var _singleLineToolbar;
  var _annotationToolbars;
  var _hideDefaultAnnotationToolbars;
  var _hideAnnotationToolbarSwitcher;
  var _initialToolbar;
  var _hideTopToolbars;
  var _hideToolbarsOnTap;
  var _hideTopAppNavBar;
  var _topAppNavBarRighBar;
  var _hideBottomToolbar;
  var _hidePresetBar;
  var _bottomToolbar;
  var _showLeadingNavButton;
  var _documentSliderEnabled;
  var _rememberLastUsedTool;
  var _readOnly;
  var _thumbnailViewEditingEnabled;
  var _annotationAuthor;
  var _continuousAnnotationEditing;
  var _annotationPermissionCheckEnabled;
  var _annotationsListEditingEnabled;
  var _userBookmarksListEditingEnabled;
  var _outlineListEditingEnabled;
  var _showNavigationListAsSidePanelOnLargeDevices;
  var _overrideBehavior;
  var _tabTitle;
  var _pageNumberIndicatorAlwaysVisible;
  var _disableEditingByAnnotationType;
  var _annotationsListFilterEnabled;
  var _hideViewModeItems;
  var _defaultEraserType;
  var _autoResizeFreeTextEnabled;
  var _restrictDownloadUsage;
  var _reflowOrientation;
  var _imageInReflowModeEnabled;
  var _annotationManagerEnabled;
  var _userId;
  var _userName;
  var _annotationManagerEditMode;
  var _annotationManagerUndoMode;
  var _annotationToolbarAlignment;
  var _hideScrollbars;
  var _quickBookmarkCreation;
  var _fullScreenModeEnabled;

  // Hygen Generated Configs (1)

  Config();

  set disabledElements(List value) => _disabledElements = value;

  set disabledTools(List value) => _disabledTools = value;

  set multiTabEnabled(bool value) => _multiTabEnabled = value;

  set customHeaders(Map<String, String> value) => _customHeaders = value;

  set fitMode(String value) => _fitMode = value;

  set layoutMode(String value) => _layoutMode = value;

  set tabletLayoutEnabled(bool value) => _tabletLayoutEnabled = value;

  set initialPageNumber(int value) => _initialPageNumber = value;

  set isBase64String(bool value) => _isBase64String = value;

  set base64FileExtension(String value) => _base64FileExtension = value;

  set hideThumbnailFilterModes(List value) => _hideThumbnailFilterModes = value;

  set longPressMenuEnabled(bool value) => _longPressMenuEnabled = value;

  set longPressMenuItems(List value) => _longPressMenuItems = value;

  set overrideLongPressMenuBehavior(List value) =>
      _overrideLongPressMenuBehavior = value;

  set hideAnnotationMenu(List value) => _hideAnnotationMenu = value;

  set annotationMenuItems(List value) => _annotationMenuItems = value;

  set overrideAnnotationMenuBehavior(List value) =>
      _overrideAnnotationMenuBehavior = value;

  set excludedAnnotationListTypes(List value) =>
      _excludedAnnotationListTypes = value;

  set exportPath(String value) => _exportPath = value;

  set openUrlPath(String value) => _openUrlPath = value;

  set openSavedCopyInNewTab(bool value) => _openSavedCopyInNewTab = value;

  set maxTabCount(int value) => _maxTabCount = value;

  set autoSaveEnabled(bool value) => _autoSaveEnabled = value;

  set showDocumentSavedToast(bool value) => _showDocumentSavedToast = value;

  set pageChangeOnTap(bool value) => _pageChangeOnTap = value;

  set showSavedSignatures(bool value) => _showSavedSignatures = value;

  set signaturePhotoPickerEnabled(bool value) =>
      _signaturePhotoPickerEnabled = value;

  /// Defines whether to enable typing to create a new signature
  ///
  /// Defaults to true.
  set signatureTypingEnabled(bool value) => _signatureTypingEnabled = value;

  /// Defines whether to enable drawing to create a new signature.
  ///
  /// iOS only. Defaults to true.
  set signatureDrawingEnabled(bool value) => _signatureDrawingEnabled = value;

  /// Whether a stylus should act like a pen when the viewer is in pan mode.
  ///
  /// If false, it will act like a finger. Defaults to true.
  set useStylusAsPen(bool value) => _useStylusAsPen;

  set signSignatureFieldWithStamps(bool value) =>
      _signSignatureFieldWithStamps = value;

  /// A list of colors that the user can select to create a signature.
  ///
  /// ```dart
  /// config.signatureColors = [
  ///   { 'red': 255, 'green': 0, 'blue': 0 },
  ///   { 'red':   0, 'green': 0, 'blue': 0 }
  /// ];
  /// ```
  ///
  /// Each color is given by a `Map<String, int>` containing RGB values, with a
  /// maximum of three colors. On Android, when this config is set, the user
  /// will not be able to customize each color shown. Defaults to black, blue,
  /// green for Android, and black, blue, red for iOS.
  set signatureColors(List value) => _signatureColors = value;

  /// Whether the annotation is selected after creation.
  ///
  /// On iOS, this functions for shape and text markup only. Defaults to true.
  set selectAnnotationAfterCreation(bool value) =>
      _selectAnnotationAfterCreation = value;

  set pageIndicatorEnabled(bool value) => _pageIndicatorEnabled = value;

  set showQuickNavigationButton(bool value) =>
      _showQuickNavigationButton = value;

  set followSystemDarkMode(bool value) => _followSystemDarkMode = value;

  set downloadDialogEnabled(bool value) => _downloadDialogEnabled = value;

  set singleLineToolbar(bool value) => _singleLineToolbar = value;

  /// A list of [CustomToolbar] objects or [DefaultToolbars] constants that define
  /// a set of annotation toolbars.
  ///
  /// ```dart
  /// var customToolItem = new CustomToolbarItem('add_page', 'Add Page', 'ic_add_blank_page_white');
  /// var customToolbar = new CustomToolbar('myToolbar', 'myToolbar', [Tools.annotationCreateArrow, customToolItem], ToolbarIcons.favorite);
  ///
  /// config.annotationToolbars = [DefaultToolbars.annotate, customToolbar];
  /// ```
  ///
  /// If used, the default toolbars no longer show. Defaults to empty.
  set annotationToolbars(List value) => _annotationToolbars = value;

  set hideDefaultAnnotationToolbars(List value) =>
      _hideDefaultAnnotationToolbars = value;

  set hideAnnotationToolbarSwitcher(bool value) =>
      _hideAnnotationToolbarSwitcher = value;

  set initialToolbar(String value) => _initialToolbar = value;

  set hideTopToolbars(bool value) => _hideTopToolbars = value;

  set hideToolbarsOnTap(bool value) => _hideToolbarsOnTap = value;

  set hideTopAppNavBar(bool value) => _hideTopAppNavBar = value;

  set topAppNavBarRightBar(List value) => _topAppNavBarRighBar = value;

  set hideBottomToolbar(bool value) => _hideBottomToolbar = value;

  set hidePresetBar(bool value) => _hidePresetBar = value;

  set bottomToolbar(List value) => _bottomToolbar = value;

  set showLeadingNavButton(bool value) => _showLeadingNavButton = value;

  set documentSliderEnabled(bool value) => _documentSliderEnabled = value;

  set rememberLastUsedTool(bool value) => _rememberLastUsedTool = value;

  set readOnly(bool value) => _readOnly = value;

  set thumbnailViewEditingEnabled(bool value) =>
      _thumbnailViewEditingEnabled = value;

  set annotationAuthor(String value) => _annotationAuthor = value;

  set continuousAnnotationEditing(bool value) =>
      _continuousAnnotationEditing = value;

  set annotationPermissionCheckEnabled(bool value) =>
      _annotationPermissionCheckEnabled = value;

  set annotationsListEditingEnabled(bool value) =>
      _annotationsListEditingEnabled = value;

  set userBookmarksListEditingEnabled(bool value) =>
      _userBookmarksListEditingEnabled = value;

  set outlineListEditingEnabled(bool value) =>
      _outlineListEditingEnabled = value;

  set showNavigationListAsSidePanelOnLargeDevices(bool value) =>
      _showNavigationListAsSidePanelOnLargeDevices = value;

  set overrideBehavior(List<String> value) => _overrideBehavior = value;

  set tabTitle(String value) => _tabTitle = value;

  set pageNumberIndicatorAlwaysVisible(bool value) =>
      _pageNumberIndicatorAlwaysVisible = value;

  set disableEditingByAnnotationType(List value) =>
      _disableEditingByAnnotationType = value;

  set annotationsListFilterEnabled(bool value) =>
      _annotationsListFilterEnabled = value;

  set hideViewModeItems(List value) => _hideViewModeItems = value;

  set defaultEraserType(String value) => _defaultEraserType = value;

  set autoResizeFreeTextEnabled(bool value) =>
      _autoResizeFreeTextEnabled = value;

  set restrictDownloadUsage(bool value) => _restrictDownloadUsage = value;

  set reflowOrientation(String value) => _reflowOrientation = value;

  set imageInReflowModeEnabled(bool value) => _imageInReflowModeEnabled = value;

  set annotationManagerEnabled(bool value) => _annotationManagerEnabled = value;

  set userId(String value) => _userId = value;

  set userName(String value) => _userName = value;

  set annotationManagerEditMode(String value) =>
      _annotationManagerEditMode = value;

  set annotationManagerUndoMode(String value) =>
      _annotationManagerUndoMode = value;

  set annotationToolbarAlignment(String value) =>
      _annotationToolbarAlignment = value;

  /// bool, optional, iOS only, defaults to false
  ///
  /// Determines whether scrollbars will be hidden on the viewer.
  set hideScrollbars(bool value) => _hideScrollbars = value;
  /// Sets the bookmark creation as a part of the toolbar
  ///
  /// Defaults to false
  set quickBookmarkCreation(bool value) => _quickBookmarkCreation = value;

  /// Whether to enable the viewer's full screen mode.
  ///
  /// Defaults to false. Android only.
  set fullScreenModeEnabled(bool value) => _fullScreenModeEnabled = value;

  // Hygen Generated Configs (2)

  Config.fromJson(Map<String, dynamic> json)
      : _disabledElements = json['disabledElements'],
        _disabledTools = json['disabledTools'],
        _multiTabEnabled = json['multiTabEnabled'],
        _customHeaders = json['customHeaders'],
        _fitMode = json['fitMode'],
        _layoutMode = json['layoutMode'],
        _tabletLayoutEnabled = json['tabletLayoutEnabled'],
        _initialPageNumber = json['initialPageNumber'],
        _isBase64String = json['isBase64String'],
        _base64FileExtension = json['base64FileExtension'],
        _hideThumbnailFilterModes = json['hideThumbnailFilterModes'],
        _longPressMenuEnabled = json['longPressMenuEnabled'],
        _longPressMenuItems = json['longPressMenuItems'],
        _overrideLongPressMenuBehavior = json['overrideLongPressMenuBehavior'],
        _hideAnnotationMenu = json['hideAnnotationMenu'],
        _annotationMenuItems = json['annotationMenuItems'],
        _overrideAnnotationMenuBehavior =
            json['overrideAnnotationMenuBehavior'],
        _excludedAnnotationListTypes = json['excludedAnnotationListTypes'],
        _exportPath = json['exportPath'],
        _openUrlPath = json['openUrlPath'],
        _openSavedCopyInNewTab = json['openSavedCopyInNewTab'],
        _maxTabCount = json['maxTabCount'],
        _autoSaveEnabled = json['autoSaveEnabled'],
        _showDocumentSavedToast = json['showDocumentSavedToast'],
        _pageChangeOnTap = json['pageChangeOnTap'],
        _showSavedSignatures = json['showSavedSignatures'],
        _signaturePhotoPickerEnabled = json['signaturePhotoPickerEnabled'],
        _signatureTypingEnabled = json['signatureTypingEnabled'],
        _signatureDrawingEnabled = json['signatureDrawingEnabled'],
        _useStylusAsPen = json['useStylusAsPen'],
        _signSignatureFieldWithStamps = json['signSignatureFieldWithStamps'],
        _signatureColors = json['signatureColors'],
        _selectAnnotationAfterCreation = json['selectAnnotationAfterCreation'],
        _pageIndicatorEnabled = json['pageIndicatorEnabled'],
        _showQuickNavigationButton = json['showQuickNavigationButton'],
        _followSystemDarkMode = json['followSystemDarkMode'],
        _downloadDialogEnabled = json['downloadDialogEnabled'],
        _singleLineToolbar = json['_singleLineToolbar'],
        _annotationToolbars = json['annotationToolbars'],
        _hideDefaultAnnotationToolbars = json['hideDefaultAnnotationToolbars'],
        _hideAnnotationToolbarSwitcher = json['hideAnnotationToolbarSwitcher'],
        _initialToolbar = json['initialToolbar'],
        _hideTopToolbars = json['hideTopToolbars'],
        _hideToolbarsOnTap = json['hideToolbarsOnTap'],
        _hideTopAppNavBar = json['hideTopAppNavBar'],
        _topAppNavBarRighBar = json['topAppNavBarRightBar'],
        _hideBottomToolbar = json['hideBottomToolbar'],
        _hidePresetBar = json['hidePresetBar'],
        _bottomToolbar = json['bottomToolbar'],
        _showLeadingNavButton = json['showLeadingNavButton'],
        _documentSliderEnabled = json['documentSliderEnabled'],
        _rememberLastUsedTool = json['rememberLastUsedTool'],
        _readOnly = json['readOnly'],
        _thumbnailViewEditingEnabled = json['thumbnailViewEditingEnabled'],
        _annotationAuthor = json['annotationAuthor'],
        _continuousAnnotationEditing = json['continuousAnnotationEditing'],
        _annotationPermissionCheckEnabled =
            json['annotationPermissionCheckEnabled'],
        _annotationsListEditingEnabled = json['annotationsListEditingEnabled'],
        _userBookmarksListEditingEnabled =
            json['userBookmarksListEditingEnabled'],
        _showNavigationListAsSidePanelOnLargeDevices =
            json['showNavigationListAsSidePanelOnLargeDevices'],
        _overrideBehavior = json['overrideBehavior'],
        _tabTitle = json['tabTitle'],
        _pageNumberIndicatorAlwaysVisible =
            json['pageNumberIndicatorAlwaysVisible'],
        _disableEditingByAnnotationType =
            json['disableEditingByAnnotationType'],
        _annotationsListFilterEnabled = json['annotationsListFilterEnabled'],
        _hideViewModeItems = json['hideViewModeItems'],
        _defaultEraserType = json['defaultEraserType'],
        _autoResizeFreeTextEnabled = json['autoResizeFreeTextEnabled'],
        _restrictDownloadUsage = json['restrictDownloadUsage'],
        _reflowOrientation = json['reflowOrientation'],
        _imageInReflowModeEnabled = json['imageInReflowModeEnabled'],
        _annotationManagerEnabled = json['annotationManagerEnabled'],
        _userId = json['userId'],
        _userName = json['userName'],
        _annotationManagerEditMode = json['annotationManagerEditMode'],
        _annotationManagerUndoMode = json['annotationManagerUndoMode'],
        _annotationToolbarAlignment = json['annotationToolbarAlignment'],
        _outlineListEditingEnabled = json['outlineListEditingEnabled'],
        _hideScrollbars = json['hideScrollbars'],
        _quickBookmarkCreation = json['quickBookmarkCreation'],

        // Hygen Generated Configs (3)
        
        _fullScreenModeEnabled = json['fullScreenModeEnabled'];

  Map<String, dynamic> toJson() => {
        'disabledElements': _disabledElements,
        'disabledTools': _disabledTools,
        'multiTabEnabled': _multiTabEnabled,
        'customHeaders': _customHeaders,
        'fitMode': _fitMode,
        'layoutMode': _layoutMode,
        'tabletLayoutEnabled': _tabletLayoutEnabled,
        'initialPageNumber': _initialPageNumber,
        'isBase64String': _isBase64String,
        'base64FileExtension': _base64FileExtension,
        'hideThumbnailFilterModes': _hideThumbnailFilterModes,
        'longPressMenuEnabled': _longPressMenuEnabled,
        'longPressMenuItems': _longPressMenuItems,
        'overrideLongPressMenuBehavior': _overrideLongPressMenuBehavior,
        'hideAnnotationMenu': _hideAnnotationMenu,
        'annotationMenuItems': _annotationMenuItems,
        'overrideAnnotationMenuBehavior': _overrideAnnotationMenuBehavior,
        'excludedAnnotationListTypes': _excludedAnnotationListTypes,
        'exportPath': _exportPath,
        'openUrlPath': _openUrlPath,
        'openSavedCopyInNewTab': _openSavedCopyInNewTab,
        'maxTabCount': _maxTabCount,
        'autoSaveEnabled': _autoSaveEnabled,
        'showDocumentSavedToast': _showDocumentSavedToast,
        'pageChangeOnTap': _pageChangeOnTap,
        'showSavedSignatures': _showSavedSignatures,
        'signaturePhotoPickerEnabled': _signaturePhotoPickerEnabled,
        'signatureTypingEnabled': _signatureTypingEnabled,
        'signatureDrawingEnabled': _signatureDrawingEnabled,
        'useStylusAsPen': _useStylusAsPen,
        'signSignatureFieldWithStamps': _signSignatureFieldWithStamps,
        'signatureColors': _signatureColors,
        'selectAnnotationAfterCreation': _selectAnnotationAfterCreation,
        'pageIndicatorEnabled': _pageIndicatorEnabled,
        'showQuickNavigationButton': _showQuickNavigationButton,
        'followSystemDarkMode': _followSystemDarkMode,
        'downloadDialogEnabled': _downloadDialogEnabled,
        'singleLineToolbar': _singleLineToolbar,
        'annotationToolbars': _annotationToolbars,
        'hideDefaultAnnotationToolbars': _hideDefaultAnnotationToolbars,
        'hideAnnotationToolbarSwitcher': _hideAnnotationToolbarSwitcher,
        'initialToolbar': _initialToolbar,
        'hideTopToolbars': _hideTopToolbars,
        'hideToolbarsOnTap': _hideToolbarsOnTap,
        'hideTopAppNavBar': _hideTopAppNavBar,
        'topAppNavBarRightBar': _topAppNavBarRighBar,
        'hideBottomToolbar': _hideBottomToolbar,
        'hidePresetBar': _hidePresetBar,
        'bottomToolbar': _bottomToolbar,
        'showLeadingNavButton': _showLeadingNavButton,
        'documentSliderEnabled': _documentSliderEnabled,
        'rememberLastUsedTool': _rememberLastUsedTool,
        'readOnly': _readOnly,
        'thumbnailViewEditingEnabled': _thumbnailViewEditingEnabled,
        'annotationAuthor': _annotationAuthor,
        'continuousAnnotationEditing': _continuousAnnotationEditing,
        'annotationPermissionCheckEnabled': _annotationPermissionCheckEnabled,
        'annotationsListEditingEnabled': _annotationsListEditingEnabled,
        'userBookmarksListEditingEnabled': _userBookmarksListEditingEnabled,
        'showNavigationListAsSidePanelOnLargeDevices':
            _showNavigationListAsSidePanelOnLargeDevices,
        'overrideBehavior': _overrideBehavior,
        'tabTitle': _tabTitle,
        'pageNumberIndicatorAlwaysVisible': _pageNumberIndicatorAlwaysVisible,
        'disableEditingByAnnotationType': _disableEditingByAnnotationType,
        'annotationsListFilterEnabled': _annotationsListFilterEnabled,
        'hideViewModeItems': _hideViewModeItems,
        'defaultEraserType': _defaultEraserType,
        'autoResizeFreeTextEnabled': _autoResizeFreeTextEnabled,
        'restrictDownloadUsage': _restrictDownloadUsage,
        'reflowOrientation': _reflowOrientation,
        'imageInReflowModeEnabled': _imageInReflowModeEnabled,
        'annotationManagerEnabled': _annotationManagerEnabled,
        'userId': _userId,
        'userName': _userName,
        'annotationManagerEditMode': _annotationManagerEditMode,
        'annotationManagerUndoMode': _annotationManagerUndoMode,
        'annotationToolbarAlignment': _annotationToolbarAlignment,
        'outlineListEditingEnabled': _outlineListEditingEnabled,
        'hideScrollbars': _hideScrollbars,
        'quickBookmarkCreation': _quickBookmarkCreation,
        'fullScreenModeEnabled': _fullScreenModeEnabled,

        // Hygen Generated Configs (4)
      };
}
