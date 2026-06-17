#import "PdftronFlutterPlugin.h"
#import "PTFlutterDocumentController.h"
#import "DocumentViewFactory.h"
#import "PTNavigationController.h"
#import <stdlib.h>

@interface PdftronFlutterPlugin () <PTTabbedDocumentViewControllerDelegate, PTDocumentControllerDelegate>

@property (nonatomic, strong) id config;
@property (nonatomic, strong) FlutterEventSink xfdfEventSink;
@property (nonatomic, strong) FlutterEventSink bookmarkEventSink;
@property (nonatomic, strong) FlutterEventSink documentLoadedEventSink;
@property (nonatomic, strong) FlutterEventSink documentErrorEventSink;
@property (nonatomic, strong) FlutterEventSink annotationChangedEventSink;
@property (nonatomic, strong) FlutterEventSink annotationsSelectedEventSink;
@property (nonatomic, strong) FlutterEventSink formFieldValueChangedEventSink;
@property (nonatomic, strong) FlutterEventSink behaviorActivatedEventSink;
@property (nonatomic, strong) FlutterEventSink longPressMenuPressedEventSink;
@property (nonatomic, strong) FlutterEventSink annotationMenuPressedEventSink;
@property (nonatomic, strong) FlutterEventSink leadingNavButtonPressedEventSink;
@property (nonatomic, strong) FlutterEventSink pageChangedEventSink;
@property (nonatomic, strong) FlutterEventSink zoomChangedEventSink;
@property (nonatomic, strong) FlutterEventSink pageMovedEventSink;
@property (nonatomic, strong) FlutterEventSink scrollChangedEventSink;
@property (nonatomic, strong) FlutterEventSink annotationToolbarItemPressedEventSink;
// Hygen Generated Event Listeners (1)
@property (nonatomic, strong) FlutterEventSink appBarButtonPressedEventSink;

@property (nonatomic, assign, getter=isWidgetView) BOOL widgetView;
@property (nonatomic, assign, getter=isMultiTabSet) BOOL multiTabSet;

@end

static void BauhubDecorateAllImportedAreaPins(PTPDFViewCtrl *pdfViewCtrl, PTPDFDoc *doc);
static NSString *BauhubWebTaskPinImageName(void);
static void BauhubScheduleDecorativeAreaPinZoomSync(PTPDFViewCtrl *pdfViewCtrl);
void BauhubSetAreaMarkupPresetColors(unsigned fillArgb, unsigned strokeArgb);
static BOOL BauhubTryUint32FromFlutterColorArg(id value, NSUInteger *outArgb);
static void BauhubApplyAreaToolDrawPreviewDefaults(PTPDFViewCtrl *pdfViewCtrl);
static void BauhubScheduleAreaPinStamp(PTPDFViewCtrl *pdfViewCtrl, int pageHint, PTAnnot *shapeAnnot);
static void BauhubRestoreTranslucentAreaMarkupAppearancesInDoc(PTPDFDoc *doc);
static int BauhubFindPageNumberForAnnotInDoc(PTPDFDoc *doc, PTAnnot *target);
static UIImage *BauhubLoadTemplateImageNamed(NSString *name);
static void BauhubScheduleReapplyBauhubAreaMarkupStyle(PTPDFViewCtrl *pdfViewCtrl, PTAnnot *annot, int pageNumber, NSString *subject);
static void BauhubApplyWebStyleStampFlagsAndDates(PTAnnot *stampAnnot);
// Forward decl so [- deleteAnnotations:] can reach it without reordering the
// rest of the bauhub area-pin section.
void PTBauhubRemoveDecorativePinsWhenParentShapeRemoved(PTPDFViewCtrl *pdfViewCtrl, PTPDFDoc *doc, PTAnnot *shapeAnnot, int pageNumber);

static BOOL BauhubXfdfAttributeStringHasBauhubAreaSubject(NSString *attrs) {
    if (attrs.length == 0) {
        return NO;
    }
    NSError *err = nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"(?i)subject\\s*=\\s*[\"'](Comment|Attachment|Task)[\"']"
                                                                        options:0
                                                                          error:&err];
    return (re != nil) && ([re numberOfMatchesInString:attrs options:0 range:NSMakeRange(0, attrs.length)] > 0);
}

/// `<squareattrs>` is invalid XFDF; ensure one leading space before the attribute list when missing.
static NSString *BauhubXfdfAttrsWithLeadingSpace(NSString *attrs) {
    if (attrs.length == 0) {
        return attrs;
    }
    unichar c = [attrs characterAtIndex:0];
    if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c]) {
        return attrs;
    }
    return [NSString stringWithFormat:@" %@", attrs];
}

/// PDFNet sometimes serializes the first trn-custom-data as an opening tag before a second trn, and emits
/// `</square>` / `</polygon>` before `<apref>` — invalid XML. Same steps as Android `repairSquarePolygonTrnCustomDataXfdfMerging` / Dart `_repairTrnCustomDataMerging`.
static NSString *BauhubRepairSquarePolygonTrnCustomDataXfdfMerging(NSString *xfdf) {
    if (xfdf.length == 0) {
        return xfdf;
    }
    NSError *err = nil;
    NSRegularExpression *reOpen = [NSRegularExpression regularExpressionWithPattern:@"(?is)<trn-custom-data(\\b[^>]*?)\"\\s*>\\s*<trn-custom-data"
                                                                            options:0
                                                                              error:&err];
    NSString *out = xfdf;
    if (reOpen && !err) {
        out = [reOpen stringByReplacingMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:@"<trn-custom-data$1\"/><trn-custom-data"];
    }
    err = nil;
    NSRegularExpression *reSpuriousClose = [NSRegularExpression regularExpressionWithPattern:@"(?is)((?:<(?:[\\w.-]+:)?trn-custom-data\\b[^>]*/\\s*>\\s*)+)</[\\w.:-]*(square|polygon)\\s*>\\s*(<apref\\b)"
                                                                                      options:0
                                                                                        error:&err];
    if (reSpuriousClose && !err) {
        out = [reSpuriousClose stringByReplacingMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:@"$1$3"];
    }
    return out;
}

static NSString *BauhubNormalizeHexForCompare(NSString *hex) {
    if (hex.length == 0) {
        return @"";
    }
    NSString *h = hex;
    if (![h hasPrefix:@"#"]) {
        h = [NSString stringWithFormat:@"#%@", h];
    }
    return [h lowercaseString];
}

/// When interior-color already differs from stroke `color`, keep it (web parity normalization must not collapse fill into stroke).
static BOOL BauhubAreaInteriorDiffersFromStroke(NSString *strokeHex, NSString *interiorHex) {
    if (interiorHex.length == 0 || strokeHex.length == 0) {
        return NO;
    }
    return ![BauhubNormalizeHexForCompare(strokeHex) isEqualToString:BauhubNormalizeHexForCompare(interiorHex)];
}

/// Aligns outgoing XFDF for Bauhub Comment/Attachment/Task squares/polygons with WebViewer exports (see bauhub-fe).
static NSString *BauhubNormalizeBauhubAreaMarkupXfdfForWebParity(NSString *xfdf) {
    if (xfdf.length == 0) {
        return xfdf;
    }
    xfdf = BauhubRepairSquarePolygonTrnCustomDataXfdfMerging(xfdf);
    NSError *err = nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"<(square|polygon)\\s([\\s\\S]*?)/\\s*>"
                                                                        options:NSRegularExpressionCaseInsensitive
                                                                          error:&err];
    if (!re || err) {
        return xfdf;
    }
    NSRegularExpression *opDouble = [NSRegularExpression regularExpressionWithPattern:@"(?i)\\bopacity\\s*=\\s*\"[^\"]*\""
                                                                                options:0
                                                                                  error:nil];
    NSRegularExpression *opSingle = [NSRegularExpression regularExpressionWithPattern:@"(?i)\\bopacity\\s*=\\s*'[^']*'"
                                                                                options:0
                                                                                  error:nil];
    NSRegularExpression *colorRe = [NSRegularExpression regularExpressionWithPattern:@"(?i)\\bcolor\\s*=\\s*\"(#?[0-9A-Fa-f]{6})\""
                                                                               options:0
                                                                                 error:nil];
    NSRegularExpression *intRe = [NSRegularExpression regularExpressionWithPattern:@"(?i)\\binterior-color\\s*=\\s*\"[^\"]*\""
                                                                             options:0
                                                                               error:nil];
    NSRegularExpression *intHexRe = [NSRegularExpression regularExpressionWithPattern:@"(?i)\\binterior-color\\s*=\\s*\"(#?[0-9A-Fa-f]{6})\""
                                                                                options:0
                                                                                  error:nil];
    NSMutableString *out = [xfdf mutableCopy];
    NSArray<NSTextCheckingResult *> *matches = [re matchesInString:out options:0 range:NSMakeRange(0, out.length)];
    for (NSTextCheckingResult *m in [matches reverseObjectEnumerator]) {
        if (m.numberOfRanges < 3) {
            continue;
        }
        NSString *attrs = [out substringWithRange:[m rangeAtIndex:2]];
        if (!BauhubXfdfAttributeStringHasBauhubAreaSubject(attrs)) {
            continue;
        }
        NSString *newAttrs = attrs;
        if ([opDouble numberOfMatchesInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length)] > 0) {
            newAttrs = [opDouble stringByReplacingMatchesInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length) withTemplate:@"opacity=\"0.3\""];
        } else if ([opSingle numberOfMatchesInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length)] > 0) {
            newAttrs = [opSingle stringByReplacingMatchesInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length) withTemplate:@"opacity='0.3'"];
        } else {
            newAttrs = [NSString stringWithFormat:@" opacity=\"0.3\" %@", newAttrs];
        }
        if ([newAttrs rangeOfString:@"dashes=" options:NSCaseInsensitiveSearch].location == NSNotFound) {
            newAttrs = [NSString stringWithFormat:@" dashes=\"\" %@", newAttrs];
        }
        NSTextCheckingResult *colorMatch = [colorRe firstMatchInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length)];
        if (colorMatch && colorMatch.numberOfRanges >= 2) {
            NSString *strokeHexRaw = [newAttrs substringWithRange:[colorMatch rangeAtIndex:1]];
            NSString *hex = strokeHexRaw;
            if (hex.length > 0 && ![hex hasPrefix:@"#"]) {
                hex = [NSString stringWithFormat:@"#%@", hex];
            }
            NSString *interiorHexRaw = nil;
            NSTextCheckingResult *intHexMatch = intHexRe ? [intHexRe firstMatchInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length)] : nil;
            if (intHexMatch && intHexMatch.numberOfRanges >= 2) {
                interiorHexRaw = [newAttrs substringWithRange:[intHexMatch rangeAtIndex:1]];
            }
            BOOL preserveInterior = BauhubAreaInteriorDiffersFromStroke(strokeHexRaw, interiorHexRaw);
            if (!preserveInterior && hex.length > 0) {
                NSString *icTemplate = [NSString stringWithFormat:@"interior-color=\"%@\"", hex];
                if ([intRe numberOfMatchesInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length)] > 0) {
                    newAttrs = [intRe stringByReplacingMatchesInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length) withTemplate:icTemplate];
                } else {
                    newAttrs = [NSString stringWithFormat:@" %@ %@", icTemplate, newAttrs];
                }
            }
        }
        NSString *tagName = [out substringWithRange:[m rangeAtIndex:1]];
        // Self-closing only: PDFNet iOS/Android XFDF import rejects a trn-custom-data child inside square/polygon.
        NSString *replacement = [NSString stringWithFormat:@"<%@%@/>", tagName, BauhubXfdfAttrsWithLeadingSpace(newAttrs)];
        [out replaceCharactersInRange:m.range withString:replacement];
    }
    NSError *errPaired = nil;
    NSRegularExpression *pairedRe = [NSRegularExpression regularExpressionWithPattern:@"(?i)<(square|polygon)(\\s[^>]*?)>\\s*</\\1\\s*>"
                                                                               options:0
                                                                                 error:&errPaired];
    if (pairedRe && !errPaired) {
        NSArray<NSTextCheckingResult *> *paired = [pairedRe matchesInString:out options:0 range:NSMakeRange(0, out.length)];
        for (NSTextCheckingResult *m in [paired reverseObjectEnumerator]) {
            if (m.numberOfRanges < 3) {
                continue;
            }
            NSString *attrs = [out substringWithRange:[m rangeAtIndex:2]];
            if (!BauhubXfdfAttributeStringHasBauhubAreaSubject(attrs)) {
                continue;
            }
            NSString *newAttrs = attrs;
            if ([opDouble numberOfMatchesInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length)] > 0) {
                newAttrs = [opDouble stringByReplacingMatchesInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length) withTemplate:@"opacity=\"0.3\""];
            } else if ([opSingle numberOfMatchesInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length)] > 0) {
                newAttrs = [opSingle stringByReplacingMatchesInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length) withTemplate:@"opacity='0.3'"];
            } else {
                newAttrs = [NSString stringWithFormat:@" opacity=\"0.3\" %@", newAttrs];
            }
            if ([newAttrs rangeOfString:@"dashes=" options:NSCaseInsensitiveSearch].location == NSNotFound) {
                newAttrs = [NSString stringWithFormat:@" dashes=\"\" %@", newAttrs];
            }
            NSTextCheckingResult *colorMatch2 = [colorRe firstMatchInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length)];
            if (colorMatch2 && colorMatch2.numberOfRanges >= 2) {
                NSString *strokeHexRaw2 = [newAttrs substringWithRange:[colorMatch2 rangeAtIndex:1]];
                NSString *hex = strokeHexRaw2;
                if (hex.length > 0 && ![hex hasPrefix:@"#"]) {
                    hex = [NSString stringWithFormat:@"#%@", hex];
                }
                NSString *interiorHexRaw2 = nil;
                NSTextCheckingResult *intHexMatch2 = intHexRe ? [intHexRe firstMatchInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length)] : nil;
                if (intHexMatch2 && intHexMatch2.numberOfRanges >= 2) {
                    interiorHexRaw2 = [newAttrs substringWithRange:[intHexMatch2 rangeAtIndex:1]];
                }
                BOOL preserveInterior2 = BauhubAreaInteriorDiffersFromStroke(strokeHexRaw2, interiorHexRaw2);
                if (!preserveInterior2 && hex.length > 0) {
                    NSString *icTemplate = [NSString stringWithFormat:@"interior-color=\"%@\"", hex];
                    if ([intRe numberOfMatchesInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length)] > 0) {
                        newAttrs = [intRe stringByReplacingMatchesInString:newAttrs options:0 range:NSMakeRange(0, newAttrs.length) withTemplate:icTemplate];
                    } else {
                        newAttrs = [NSString stringWithFormat:@" %@ %@", icTemplate, newAttrs];
                    }
                }
            }
            NSString *tagName = [out substringWithRange:[m rangeAtIndex:1]];
            NSString *replacement = [NSString stringWithFormat:@"<%@%@/>", tagName, BauhubXfdfAttrsWithLeadingSpace(newAttrs)];
            [out replaceCharactersInRange:m.range withString:replacement];
        }
    }
    return [out copy];
}

/// After folding to \<square .../\>, a leftover \</square\> (or trn-custom-data + \</square\>) breaks libxml ("annots" vs "square"). Strip those orphans.
static NSString *BauhubStripOrphanClosingAfterSelfClosedAreaMarkup(NSString *xfdf) {
    if (xfdf.length == 0) {
        return xfdf;
    }
    NSRegularExpressionOptions opts = NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators;
    NSArray<NSString *> *patterns = @[
        @"(?is)(<[\\w.:-]*square\\b[^>]*/\\s*>)\\s*<(?:[\\w.-]+:)?trn-custom-data\\b[\\s\\S]*?/\\s*>\\s*</[\\w.:-]*square\\s*>",
        @"(?is)(<[\\w.:-]*square\\b[^>]*/\\s*>)\\s*</[\\w.:-]*square\\s*>",
        @"(?is)(<[\\w.:-]*polygon\\b[^>]*/\\s*>)\\s*<(?:[\\w.-]+:)?trn-custom-data\\b[\\s\\S]*?/\\s*>\\s*</[\\w.:-]*polygon\\s*>",
        @"(?is)(<[\\w.:-]*polygon\\b[^>]*/\\s*>)\\s*</[\\w.:-]*polygon\\s*>",
    ];
    NSString *out = xfdf;
    for (NSUInteger pass = 0; pass < 32; pass++) {
        NSUInteger lenBefore = out.length;
        for (NSString *pattern in patterns) {
            NSError *err = nil;
            NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:opts error:&err];
            if (!re || err) {
                continue;
            }
            out = [re stringByReplacingMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:@"$1"];
        }
        if (out.length == lenBefore) {
            break;
        }
    }
    return out;
}

/// PDFNet mobile XFDF import rejects WebViewer-style square/polygon with a trn-custom-data child; fold back to self-closing tags.
/// Matches optional XML prefixes (e.g. xfdf:square) and uses [\s\S]*? for trn-custom-data so attribute values cannot break [^>]*.
static NSString *BauhubDenormalizeBauhubAreaMarkupXfdfForMobileImport(NSString *xfdf) {
    if (xfdf.length == 0) {
        return xfdf;
    }
    xfdf = BauhubRepairSquarePolygonTrnCustomDataXfdfMerging(xfdf);
    NSString *out = BauhubStripOrphanClosingAfterSelfClosedAreaMarkup(xfdf);
    NSRegularExpressionOptions opts = NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators;
    NSArray<NSString *> *patterns = @[
        @"(?is)<([\\w.:-]*square)(\\s[^>]*?)>\\s*<(?:[\\w.-]+:)?trn-custom-data\\b[\\s\\S]*?/\\s*>\\s*</[\\w.:-]*square\\s*>",
        @"(?is)<([\\w.:-]*polygon)(\\s[^>]*?)>\\s*<(?:[\\w.-]+:)?trn-custom-data\\b[\\s\\S]*?/\\s*>\\s*</[\\w.:-]*polygon\\s*>",
        @"(?is)<([\\w.:-]*square)(\\s[^>]*?)>\\s*<(?:[\\w.-]+:)?trn-custom-data\\b[\\s\\S]*?</(?:[\\w.-]+:)?trn-custom-data\\s*>\\s*</[\\w.:-]*square\\s*>",
        @"(?is)<([\\w.:-]*polygon)(\\s[^>]*?)>\\s*<(?:[\\w.-]+:)?trn-custom-data\\b[\\s\\S]*?</(?:[\\w.-]+:)?trn-custom-data\\s*>\\s*</[\\w.:-]*polygon\\s*>",
    ];
    for (NSUInteger pass = 0; pass < 32; pass++) {
        NSUInteger lenBefore = out.length;
        for (NSString *pattern in patterns) {
            NSError *err = nil;
            NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:opts error:&err];
            if (!re || err) {
                continue;
            }
            out = [re stringByReplacingMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:@"<$1$2/>"];
        }
        if (out.length == lenBefore) {
            break;
        }
    }
    out = BauhubStripOrphanClosingAfterSelfClosedAreaMarkup(out);
    return out;
}

@implementation PdftronFlutterPlugin

#pragma mark - Initialization

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar
{
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"pdftron_flutter"
                                     binaryMessenger:[registrar messenger]];
    

    
    PdftronFlutterPlugin* instance = [[PdftronFlutterPlugin alloc] init];
    instance.widgetView = NO;
    
    [registrar addMethodCallDelegate:instance channel:channel];
    
    [instance registerEventChannels:[registrar messenger]];
    [PdftronFlutterPlugin overrideControllerClasses];
    
    DocumentViewFactory* documentViewFactory =
    [[DocumentViewFactory alloc] initWithMessenger:registrar.messenger];
    [registrar registerViewFactory:documentViewFactory withId:@"pdftron_flutter/documentview"];
}

+ (PdftronFlutterPlugin *)registerWithFrame:(CGRect)frame viewIdentifier:(int64_t)viewId messenger:(NSObject<FlutterBinaryMessenger> *)messenger
{
    NSString* channelName = [NSString stringWithFormat:@"pdftron_flutter/documentview_%lld", viewId];
    FlutterMethodChannel* channel = [FlutterMethodChannel methodChannelWithName:channelName binaryMessenger:messenger];
    
    PdftronFlutterPlugin* instance = [[PdftronFlutterPlugin alloc] init];
    instance.widgetView = YES;
    
    __weak __typeof__(instance) weakInstance = instance;
    [channel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
        __strong __typeof__(weakInstance) instance = weakInstance;
        if (instance) {
            [instance handleMethodCall:call result:result];
        }
    }];
    
    [instance registerEventChannels:messenger];
    
    [instance initTabbedDocumentViewController];
    [instance presentTabbedDocumentViewController];
    
    return instance;
}

- (void)initTabbedDocumentViewController
{
    // Create and wrap a tabbed controller in a navigation controller.
    self.tabbedDocumentViewController = [[PTFlutterTabbedDocumentController alloc] init];
    
    self.tabbedDocumentViewController.delegate = self;
    self.tabbedDocumentViewController.tabsEnabled = NO;
    
    NSMutableArray *tempFiles = [[NSMutableArray alloc] init];
    [(PTFlutterTabbedDocumentController *)(self.tabbedDocumentViewController) setTempFiles:[tempFiles mutableCopy]];
    
    self.tabbedDocumentViewController.viewControllerClass = [PTFlutterDocumentController class];
    
    // Widget-embedded viewer: tabs are disabled and each widget instance represents a single document session.
    // Restoring previously persisted tab items from an earlier widget lifetime causes PDFTron to treat the
    // reopened URL as an already-loaded tab, so `viewWillLayoutSubviews` never flips `needsDocumentLoaded`
    // and the `documentLoadedFromFilePath:` event is never delivered to Flutter — leaving `isLoading`
    // stuck at `true` and hiding our overlays (annotation toolbar, activity feed button, etc.).
    // Skip restoration entirely in widget mode; PTDocumentTabManager has no items so a subsequent
    // `saveItems` on layout will persist an empty set and wipe out the stale state from the previous
    // widget lifetime.
    if (!self.isWidgetView) {
        [self.tabbedDocumentViewController.tabManager restoreItems];
    }
    
    self.tabbedDocumentViewController.restorationIdentifier = [NSUUID UUID].UUIDString;
}

- (void)presentTabbedDocumentViewController
{
    PTNavigationController *navigationController = [[PTNavigationController alloc] initWithRootViewController:self.tabbedDocumentViewController];
    
    navigationController.tabbedDocumentViewController = self.tabbedDocumentViewController;
    
    UIViewController *presentingViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    
    if (self.isWidgetView) {
        [presentingViewController addChildViewController:navigationController];
        [navigationController didMoveToParentViewController:presentingViewController];
        
    } else {
        navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
        
        // Show navigation (and tabbed) controller.
        [presentingViewController presentViewController:navigationController animated:YES completion:nil];
        
    }
}

+ (void)overrideControllerClasses
{
    [PTOverrides overrideClass:[PTDocumentController class] withClass:[PTFlutterDocumentController class]];
    
    [PTOverrides overrideClass:[PTThumbnailsViewController class] withClass:[FLThumbnailsViewController class]];
}

- (void)registerEventChannels:(NSObject<FlutterBinaryMessenger> *)messenger
{
    FlutterEventChannel* xfdfEventChannel = [FlutterEventChannel eventChannelWithName:PTExportAnnotationCommandEventKey binaryMessenger:messenger];

    FlutterEventChannel* bookmarkEventChannel = [FlutterEventChannel eventChannelWithName:PTExportBookmarkEventKey binaryMessenger:messenger];

    FlutterEventChannel* documentLoadedEventChannel = [FlutterEventChannel eventChannelWithName:PTDocumentLoadedEventKey binaryMessenger:messenger];
    
    FlutterEventChannel* documentErrorEventChannel = [FlutterEventChannel eventChannelWithName:PTDocumentErrorEventKey binaryMessenger:messenger];
    
    FlutterEventChannel* annotationChangedEventChannel = [FlutterEventChannel eventChannelWithName:PTAnnotationChangedEventKey binaryMessenger:messenger];
    
    FlutterEventChannel* annotationsSelectedEventChannel = [FlutterEventChannel eventChannelWithName:PTAnnotationsSelectedEventKey binaryMessenger:messenger];
    
    FlutterEventChannel* formFieldValueChangedEventChannel = [FlutterEventChannel eventChannelWithName:PTFormFieldValueChangedEventKey binaryMessenger:messenger];
    
    FlutterEventChannel* behaviorActivatedEventChannel = [FlutterEventChannel eventChannelWithName:PTBehaviorActivatedEventKey binaryMessenger:messenger];
    
    FlutterEventChannel* longPressMenuPressedEventChannel = [FlutterEventChannel eventChannelWithName:PTLongPressMenuPressedEventKey binaryMessenger:messenger];
    
    FlutterEventChannel* annotationMenuPressedEventChannel = [FlutterEventChannel eventChannelWithName:PTAnnotationMenuPressedEventKey binaryMessenger:messenger];

    FlutterEventChannel* leadingNavButtonPressedEventChannel = [FlutterEventChannel eventChannelWithName:PTLeadingNavButtonPressedEventKey binaryMessenger:messenger];

    FlutterEventChannel* pageChangedEventChannel = [FlutterEventChannel eventChannelWithName:PTPageChangedEventKey binaryMessenger:messenger];

    FlutterEventChannel* zoomChangedEventChannel = [FlutterEventChannel eventChannelWithName:PTZoomChangedEventKey binaryMessenger:messenger];
    
    FlutterEventChannel* pageMovedEventChannel = [FlutterEventChannel eventChannelWithName:PTPageMovedEventKey binaryMessenger:messenger];

    FlutterEventChannel* scrollChangedEventChannel = [FlutterEventChannel eventChannelWithName:PTScrollChangedEventKey binaryMessenger:messenger];

    [xfdfEventChannel setStreamHandler:self];
    
    [bookmarkEventChannel setStreamHandler:self];
    
    [documentLoadedEventChannel setStreamHandler:self];
    
    [documentErrorEventChannel setStreamHandler:self];
    
    [annotationChangedEventChannel setStreamHandler:self];
    
    [annotationsSelectedEventChannel setStreamHandler:self];
    
    [formFieldValueChangedEventChannel setStreamHandler:self];
    
    [behaviorActivatedEventChannel setStreamHandler:self];

    [longPressMenuPressedEventChannel setStreamHandler:self];
    
    [annotationMenuPressedEventChannel setStreamHandler:self];

    [leadingNavButtonPressedEventChannel setStreamHandler:self];
    
    [pageChangedEventChannel setStreamHandler:self];
    
    [zoomChangedEventChannel setStreamHandler:self];
    
    [pageMovedEventChannel setStreamHandler:self];

    [scrollChangedEventChannel setStreamHandler:self];

    // Hygen Generated Event Listeners (2)
    FlutterEventChannel* annotationToolbarItemPressedEventChannel = [FlutterEventChannel eventChannelWithName:PTAnnotationToolbarItemPressedEventKey binaryMessenger:messenger];

    [annotationToolbarItemPressedEventChannel setStreamHandler:self];
    
    FlutterEventChannel* appBarButtonPressedEventChannel = [FlutterEventChannel eventChannelWithName:PTAppBarButtonPressedEventKey binaryMessenger:messenger];

    [appBarButtonPressedEventChannel setStreamHandler:self];

    FlutterEventChannel* bauhubPolygonStateEventChannel = [FlutterEventChannel eventChannelWithName:PTBauhubPolygonStateEventKey binaryMessenger:messenger];
    [bauhubPolygonStateEventChannel setStreamHandler:self];
}

#pragma mark - Configurations

+ (void)configureTabbedDocumentViewController:(PTTabbedDocumentViewController*)tabbedDocumentViewController withConfig:(NSString*)config
{

    if(config && ![config isEqualToString:@"null"])
    {
        //convert from json to dict
        id foundationObject = [PdftronFlutterPlugin PT_JSONStringToId:config];
        
        if([foundationObject isKindOfClass:[NSNull class]]) {
            return;
        }
        
        NSDictionary* configPairs = [PdftronFlutterPlugin PT_idAsNSDict:foundationObject];
        
        if(configPairs)
        {
            for (NSString* key in configPairs.allKeys) {
                if ([key isEqualToString:PTMultiTabEnabledKey]) {
                    NSError* error;
                    NSNumber* multiTabValue = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTMultiTabEnabledKey class:[NSNumber class] error:&error];
                    
                    if (error) {
                        NSLog(@"An error occurs with config %@: %@", PTMultiTabEnabledKey, error.localizedDescription);
                        continue;
                    } else if (multiTabValue) {
                        tabbedDocumentViewController.tabsEnabled = [multiTabValue boolValue];
                    }
                }
                else if ([key isEqualToString:PTMaxTabCountKey]) {
                    NSError* error;
                    NSNumber* maxTabCount = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTMaxTabCountKey class:[NSNumber class] error:&error];
                    
                    if (!error && maxTabCount) {
                        tabbedDocumentViewController.maximumTabCount = [maxTabCount intValue];
                    }
                }
            }
        }
        else
        {
            NSLog(@"config JSON object not in expected dictionary format.");
        }
    }
}

+ (void)configureDocumentController:(PTFlutterDocumentController*)documentController withConfig:(NSString*)config
{

    [documentController initViewerSettings];
    
    if (config.length == 0 || [config isEqualToString:@"null"]) {
        [documentController applyViewerSettings];
        return;
    }
   
    //convert from json to dict
    id foundationObject = [PdftronFlutterPlugin PT_JSONStringToId:config];
    
    if (![foundationObject isKindOfClass:[NSNull class]]) {
        
        NSDictionary* configPairs = [PdftronFlutterPlugin PT_idAsNSDict:foundationObject];
        
        if(configPairs)
        {
            
            NSError* error;
            
            for (NSString* key in configPairs.allKeys) {
                if([key isEqualToString:PTDisabledToolsKey])
                {
                    
                    NSArray* toolsToDisable = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTDisabledToolsKey class:[NSArray class] error:&error];
                    
                    if (!error && toolsToDisable) {
                        [self disableTools:toolsToDisable documentController:documentController];
                    }
                }
                else if([key isEqualToString:PTDisabledElementsKey])
                {
                    
                    NSArray* elementsToDisable = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTDisabledElementsKey class:[NSArray class] error:&error];
                    
                    if (!error && elementsToDisable) {
                        [self disableElements:(NSArray*)elementsToDisable documentController:documentController];
                    }
                }
                else if ([key isEqualToString:PTCustomHeadersKey]) {
                    
                    NSDictionary* customHeaders = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTCustomHeadersKey class:[NSDictionary class] error:&error];
                    
                    if (!error && customHeaders) {
                        documentController.additionalHTTPHeaders = customHeaders;
                    }
                }
                else if ([key isEqualToString:PTMultiTabEnabledKey]) {
                    // Handled by tabbed config.
                }
                else if ([key isEqualToString:PTMaxTabCountKey]) {
                    // Handled by tabbed config.
                }
                else if ([key isEqualToString:PTFitModeKey]) {
                    
                    NSString* fitMode = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTFitModeKey class:[NSString class] error:&error];
                    
                    if (!error && fitMode) {
                        [documentController setFitMode:fitMode];
                    }
                }
                else if ([key isEqualToString:PTLayoutModeKey]) {
                    
                    NSString* layoutMode = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTLayoutModeKey class:[NSString class] error:&error];
                    
                    if (!error && layoutMode) {
                        [documentController setLayoutMode:layoutMode];
                    }
                }
                else if ([key isEqualToString:PTInitialPageNumberKey]) {
                    
                    NSNumber* initialPageNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTInitialPageNumberKey class:[NSNumber class] error:&error];
                    
                    if (!error && initialPageNumber) {
                        [documentController setInitialPageNumber:[initialPageNumber intValue]];
                    }
                }
                else if ([key isEqualToString:PTIsBase64StringKey]) {
                    
                    NSNumber* isBase64 = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTIsBase64StringKey class:[NSNumber class] error:&error];
                    
                    if (!error && isBase64) {
                        [documentController setBase64:[isBase64 boolValue]];
                    }
                }
                else if ([key isEqualToString:PTHideThumbnailFilterModesKey]) {
                    
                    NSArray* hideThumbnailFilterModes = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTHideThumbnailFilterModesKey class:[NSArray class] error:&error];
                    
                    if (!error && hideThumbnailFilterModes) {
                        [documentController setHideThumbnailFilterModes: hideThumbnailFilterModes];
                    }
                }
                else if ([key isEqualToString:PTDocumentSliderEnabledKey]) {
                    
                    NSNumber* documentSliderEnabled = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTDocumentSliderEnabledKey class:[NSNumber class] error:&error];
                    
                    if (!error && documentSliderEnabled) {
                        [documentController setDocumentSliderEnabled:[documentSliderEnabled boolValue]];
                    }
                }
                else if ([key isEqualToString:PTLongPressMenuEnabled]) {
                    
                    NSNumber* longPressMenuEnabledNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTLongPressMenuEnabled class:[NSNumber class] error:&error];
                    
                    if (!error && longPressMenuEnabledNumber) {
                        [documentController setLongPressMenuEnabled:[longPressMenuEnabledNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTLongPressMenuItems]) {
                    
                    NSArray* longPressMenuItems = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTLongPressMenuItems class:[NSArray class] error:&error];
                    
                    if (!error && longPressMenuItems) {
                        [documentController setLongPressMenuItems:longPressMenuItems];
                    }
                }
                else if ([key isEqualToString:PTOverrideLongPressMenuBehavior]) {
                    
                    NSArray* overrideLongPressMenuBehavior = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTOverrideLongPressMenuBehavior class:[NSArray class] error:&error];
                    
                    if (!error && overrideLongPressMenuBehavior) {
                        [documentController setOverrideLongPressMenuBehavior:overrideLongPressMenuBehavior];
                    }
                }
                else if ([key isEqualToString:PTHideAnnotationMenu]) {
                    
                    NSArray* hideAnnotationMenuTools = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTHideAnnotationMenu class:[NSArray class] error:&error];
                    
                    if (!error && hideAnnotationMenuTools) {
                        [documentController setHideAnnotMenuTools:hideAnnotationMenuTools];
                    }
                }
                else if ([key isEqualToString:PTAnnotationMenuItems]) {
                    
                    NSArray* annotationMenuItems = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTAnnotationMenuItems class:[NSArray class] error:&error];
                    
                    if (!error && annotationMenuItems) {
                        [documentController setAnnotationMenuItems:annotationMenuItems];
                    }
                }
                else if ([key isEqualToString:PTOverrideAnnotationMenuBehavior]) {
                    
                    NSArray* overrideAnnotationMenuBehavior = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTOverrideAnnotationMenuBehavior class:[NSArray class] error:&error];
                    
                    if (!error && overrideAnnotationMenuBehavior) {
                        [documentController setOverrideAnnotationMenuBehavior:overrideAnnotationMenuBehavior];
                    }
                }
                else if ([key isEqualToString:PTExcludedAnnotationListTypesKey]) {
                    
                    NSArray* excludedAnnotationListTypes = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTExcludedAnnotationListTypesKey class:[NSArray class] error:&error];
                    
                    if (!error && excludedAnnotationListTypes) {
                        [documentController setExcludedAnnotationListTypes:excludedAnnotationListTypes];
                    }
                }
                else if ([key isEqualToString:PTAutoSaveEnabledKey]) {
                    
                    NSNumber* autoSaveEnabledNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTAutoSaveEnabledKey class:[NSNumber class] error:&error];
                    if (!error && autoSaveEnabledNumber) {
                        [documentController setAutoSaveEnabled:[autoSaveEnabledNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTPageChangeOnTapKey]) {
                    
                    NSNumber* pageChangeOnTapNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTPageChangeOnTapKey class:[NSNumber class] error:&error];
                    if (!error && pageChangeOnTapNumber) {
                        [documentController setPageChangesOnTap:[pageChangeOnTapNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTShowSavedSignaturesKey]) {
                    
                    NSNumber* showSavedSignatureNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTShowSavedSignaturesKey class:[NSNumber class] error:&error];
                    if (!error && showSavedSignatureNumber) {
                        [documentController setShowSavedSignatures:[showSavedSignatureNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTSignaturePhotoPickerEnabledKey]) {
                    
                    NSNumber* signaturePhotoPickerEnabledNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTSignaturePhotoPickerEnabledKey class:[NSNumber class] error:&error];
                    if (!error && signaturePhotoPickerEnabledNumber) {
                        [documentController setSignaturePhotoPickerEnabled:[signaturePhotoPickerEnabledNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTSignatureTypingEnabledKey]) {
                    
                    NSNumber* signatureTypingEnabledNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTSignatureTypingEnabledKey class:[NSNumber class] error:&error];
                    if (!error && signatureTypingEnabledNumber) {
                        [documentController setSignatureTypingEnabled:[signatureTypingEnabledNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTSignatureDrawingEnabledKey]) {
                    
                    NSNumber* signatureDrawingEnabledNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTSignatureDrawingEnabledKey class:[NSNumber class] error:&error];
                    if (!error && signatureDrawingEnabledNumber) {
                        [documentController setSignatureDrawingEnabled:[signatureDrawingEnabledNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTUseStylusAsPenKey]) {
                    
                    NSNumber* useStylusAsPenNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTUseStylusAsPenKey class:[NSNumber class] error:&error];
                    if (!error && useStylusAsPenNumber) {
                        [documentController setUseStylusAsPen:[useStylusAsPenNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTSignSignatureFieldWithStampsKey]) {
                    
                    NSNumber* signSignatureFieldsWithStampsNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTSignSignatureFieldWithStampsKey class:[NSNumber class] error:&error];
                    if (!error && signSignatureFieldsWithStampsNumber) {
                        [documentController setSignSignatureFieldsWithStamps:[signSignatureFieldsWithStampsNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTSignatureColorsKey]) {
                    
                    NSArray* signatureColors = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTSignatureColorsKey class:[NSArray class] error:&error];
                    
                    if (!error && signatureColors) {
                        [documentController setSignatureColors:signatureColors];
                    }
                }
                else if ([key isEqualToString:PTSelectAnnotationAfterCreationKey]) {
                    
                    NSNumber* selectAnnotAfterCreationNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTSelectAnnotationAfterCreationKey class:[NSNumber class] error:&error];
                    
                    if (!error && selectAnnotAfterCreationNumber) {
                        [documentController setSelectAnnotationAfterCreation:[selectAnnotAfterCreationNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTPageIndicatorEnabledKey]) {
                    
                    NSNumber* pageIndicatorEnabledNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTPageIndicatorEnabledKey class:[NSNumber class] error:&error];
                    
                    if (!error && pageIndicatorEnabledNumber) {
                        [documentController setPageIndicatorEnabled:[pageIndicatorEnabledNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTPageNumberIndicatorAlwaysVisibleKey]) {

                    NSNumber* pageIndicatorAlwaysVisibleNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTPageNumberIndicatorAlwaysVisibleKey class:[NSNumber class] error:&error];

                    if (!error && pageIndicatorAlwaysVisibleNumber) {
                        [documentController setPageIndicatorAlwaysVisible:[pageIndicatorAlwaysVisibleNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTShowQuickNavigationButtonKey]) {
                    
                    NSNumber *showQuickNavButton = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTShowQuickNavigationButtonKey class:[NSNumber class] error:&error];
                    
                    if (!error && showQuickNavButton) {
                        documentController.showQuickNavigationButton = [showQuickNavButton boolValue];
                    }
                }
                else if ([key isEqualToString:PTFollowSystemDarkModeKey]) {
                    // Android only.
                }
                else if ([key isEqualToString:PTAnnotationToolbarsKey]) {
                    
                    NSArray* annotationToolbars = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTAnnotationToolbarsKey class:[NSArray class] error:&error];
                    
                    if (!error && annotationToolbars) {
                        documentController.annotationToolbars = annotationToolbars;
                    }
                }
                else if ([key isEqualToString:PTHideDefaultAnnotationToolbarsKey]) {
                    
                    NSArray* hideDefaultAnnotationToolbars = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTHideDefaultAnnotationToolbarsKey class:[NSArray class] error:&error];
                    
                    if (!error && hideDefaultAnnotationToolbars) {
                        documentController.hideDefaultAnnotationToolbars = hideDefaultAnnotationToolbars;
                    }
                }
                else if ([key isEqualToString:PTHideAnnotationToolbarSwitcherKey]) {
                    
                    NSNumber* hideAnnotationToolbarSwitcherNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTHideAnnotationToolbarSwitcherKey class:[NSNumber class] error:&error];
                    
                    if (!error && hideAnnotationToolbarSwitcherNumber) {
                        documentController.annotationToolbarSwitcherHidden = [hideAnnotationToolbarSwitcherNumber boolValue];
                    }
                }
                else if ([key isEqualToString:PTInitialToolbarKey]) {
                    
                    NSString *initialToolbar = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTInitialToolbarKey class:[NSString class] error:&error];
                    
                    if (!error && initialToolbar) {
                        documentController.initialToolbar = initialToolbar;
                    }
                }
                else if ([key isEqualToString:PTHideTopToolbarsKey]) {
                    
                    NSNumber* hideTopToolbarsNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTHideTopToolbarsKey class:[NSNumber class] error:&error];
                    
                    if (!error && hideTopToolbarsNumber) {
                        documentController.topToolbarsHidden = [hideTopToolbarsNumber boolValue];
                    }
                }
                else if ([key isEqualToString:PTHideToolbarsOnTapKey]) {
                    
                    NSNumber* hideToolbarsOnTapNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTHideToolbarsOnTapKey class:[NSNumber class] error:&error];
                    
                    if (!error && hideToolbarsOnTapNumber) {
                        documentController.toolbarsHiddenOnTap = [hideToolbarsOnTapNumber boolValue];
                    }
                }
                else if ([key isEqualToString:PTHideTopAppNavBarKey]) {
                    
                    NSNumber* hideTopAppNavBarNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTHideTopAppNavBarKey class:[NSNumber class] error:&error];
                    
                    if (!error && hideTopAppNavBarNumber) {
                        documentController.topAppNavBarHidden = [hideTopAppNavBarNumber boolValue];
                    }
                }
                else if ([key isEqualToString:PTTopAppNavBarRightBarKey]) {
                    
                    NSArray *topAppNavBarRightBar = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTTopAppNavBarRightBarKey class:[NSArray class] error:&error];
                    
                    if (!error && topAppNavBarRightBar) {
                        documentController.topAppNavBarRightBar = topAppNavBarRightBar;
                    }
                }
                else if ([key isEqualToString:PTHideBottomToolbarKey]) {
                    
                    NSNumber* hideBottomToolbarNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTHideBottomToolbarKey class:[NSNumber class] error:&error];
                    
                    if (!error && hideBottomToolbarNumber) {
                        documentController.bottomToolbarHidden = [hideBottomToolbarNumber boolValue];
                    }
                }
                else if ([key isEqualToString:PTBottomToolbarKey]) {
                    NSArray *bottomToolbar = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTBottomToolbarKey class:[NSArray class] error:&error];
                    
                    if (!error && bottomToolbar) {
                        documentController.bottomToolbar = bottomToolbar;
                    }
                }
                else if ([key isEqualToString:PTShowLeadingNavButtonKey]) {
                    
                    NSNumber* showLeadingNavButtonNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTShowLeadingNavButtonKey class:[NSNumber class] error:&error];
                    
                    if (!error && showLeadingNavButtonNumber) {
                        [documentController setShowNavButton:[showLeadingNavButtonNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTReadOnlyKey]) {
                    
                    NSNumber* readOnlyNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTReadOnlyKey class:[NSNumber class] error:&error];
                    
                    if (!error && readOnlyNumber) {
                        [documentController setReadOnly:[readOnlyNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTThumbnailViewEditingEnabledKey]) {
                    
                    NSNumber* thumbnailViewEditingEnabledNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTThumbnailViewEditingEnabledKey class:[NSNumber class] error:&error];
                    
                    if (!error && thumbnailViewEditingEnabledNumber) {
                        [documentController setThumbnailEditingEnabled:[thumbnailViewEditingEnabledNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTAnnotationAuthorKey]) {
                    
                    NSString* annotationAuthor = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTAnnotationAuthorKey class:[NSString class] error:&error];
                    
                    if (!error && annotationAuthor) {
                        [documentController setAnnotationAuthor:annotationAuthor];
                    }
                }
                else if ([key isEqualToString:PTContinuousAnnotationEditingKey]) {
                    
                    NSNumber* contEditingNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTContinuousAnnotationEditingKey class:[NSNumber class] error:&error];
                    
                    if (!error && contEditingNumber) {
                        [documentController setContinuousAnnotationEditingEnabled:[contEditingNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTAnnotationPermissionCheckEnabledKey]) {
                    
                    NSNumber* checkEnabledNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTAnnotationPermissionCheckEnabledKey class:[NSNumber class] error:&error];
                    
                    if (!error && checkEnabledNumber) {
                        
                        [documentController setAnnotationPermissionCheckEnabled:[checkEnabledNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTAnnotationsListEditingEnabledKey]) {
                    
                    NSNumber* annotationsListEditingEnabled = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTAnnotationsListEditingEnabledKey class:[NSNumber class] error:&error];
                    
                    if (!error && annotationsListEditingEnabled) {
                        
                        [documentController setAnnotationsListEditingEnabled:[annotationsListEditingEnabled boolValue]];
                    }
                }
                else if ([key isEqualToString:PTUserBookmarksListEditingEnabledKey]) {
                    
                    NSNumber* userBookmarksListEditingEnabled = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTUserBookmarksListEditingEnabledKey class:[NSNumber class] error:&error];
                    
                    if (!error && userBookmarksListEditingEnabled) {
                        
                        [documentController setUserBookmarksListEditingEnabled:[userBookmarksListEditingEnabled boolValue]];
                    }
                }
                else if ([key isEqualToString:PTOutlineListEditingEnabledKey]) {
                    
                    NSNumber* outlineListEditingEnabled = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTOutlineListEditingEnabledKey class:[NSNumber class] error:&error];
                    
                    if (!error && outlineListEditingEnabled) {
                        
                        [documentController setOutlineListEditingEnabled:[outlineListEditingEnabled boolValue]];
                    }
                }
                else if ([key isEqualToString:PTShowNavigationListAsSidePanelOnLargeDevicesKey]) {
                    
                    NSNumber* showNavigationListAsSidePanelOnLargeDevices = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTShowNavigationListAsSidePanelOnLargeDevicesKey class:[NSNumber class] error:&error];
                    
                    if (!error && showNavigationListAsSidePanelOnLargeDevices) {
                        
                        [documentController setShowNavigationListAsSidePanelOnLargeDevices:[showNavigationListAsSidePanelOnLargeDevices boolValue]];
                    }
                }
                else if ([key isEqualToString:PTOverrideBehaviorKey]) {
                    
                    NSArray* overrideBehavior = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTOverrideBehaviorKey class:[NSArray class] error:&error];
                    
                    if (!error && overrideBehavior) {
                        [documentController setOverrideBehavior:overrideBehavior];
                    }
                }
                else if ([key isEqualToString:PTTabTitleKey]) {
                    
                    NSString* tabTitle = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTTabTitleKey class:[NSString class] error:&error];
                    
                    if (!error && tabTitle) {
                        [documentController setTabTitle:tabTitle];
                    }
                }
                else if ([key isEqualToString:PTDisableEditingByAnnotationTypeKey])
                {
                    
                    NSArray* uneditableAnnotTypes = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTDisableEditingByAnnotationTypeKey class:[NSArray class] error:&error];
                    
                    if (!error && uneditableAnnotTypes) {
                        [documentController setUneditableAnnotTypes:uneditableAnnotTypes];
                    }
                }
                else if ([key isEqualToString:PTHideViewModeItemsKey])
                {
                    
                    NSArray* viewModeItems = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTHideViewModeItemsKey class:[NSArray class] error:&error];
                    
                    if (!error && viewModeItems) {
                        [documentController hideViewModeItems:viewModeItems];
                    }
                }
                else if ([key isEqualToString:PTDefaultEraserTypeKey])
                {
                    
                    NSString* defaultEraserType = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTDefaultEraserTypeKey class:[NSString class] error:&error];
                    
                    if (!error && defaultEraserType) {
                        [documentController setDefaultEraserType:defaultEraserType];
                    }
                }
                else if ([key isEqualToString:PTAutoResizeFreeTextEnabledKey]) 
                {
                    
                    NSNumber *autoResizeFreeTextEnabledNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTAutoResizeFreeTextEnabledKey class:[NSNumber class] error:&error];
                    
                    if (!error && autoResizeFreeTextEnabledNumber) {
                        documentController.autoResizeFreeTextEnabled = [autoResizeFreeTextEnabledNumber boolValue];
                    }
                }
                else if ([key isEqualToString:PTRestrictDownloadUsageKey]) 
                {
                    
                    NSNumber *restrictDownloadUsageNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTRestrictDownloadUsageKey class:[NSNumber class] error:&error];
                    
                    if (!error && restrictDownloadUsageNumber) {
                        documentController.restrictDownloadUsage = [restrictDownloadUsageNumber boolValue];
                    }
                }
                else if ([key isEqualToString:PTReflowOrientationKey]) 
                {
                    
                    NSString *reflowOrientation = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTReflowOrientationKey class:[NSString class] error:&error];
                    
                    if (!error && reflowOrientation) {
                        [documentController setReflowOrientation:reflowOrientation];
                    }
                }
                else if ([key isEqualToString:PTImageInReflowModeEnabledKey]) 
                {
                    
                    NSNumber *imageInReflowModeEnabledNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTImageInReflowModeEnabledKey class:[NSNumber class] error:&error];
                    
                    if (!error && imageInReflowModeEnabledNumber) {
                        [documentController setImageInReflowModeEnabled:[imageInReflowModeEnabledNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTAnnotationManagerEnabledKey])
                {
                    NSNumber* annotationManagerEnabledNumber = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTAnnotationManagerEnabledKey class:[NSNumber class] error:&error];
                    
                    if (!error && annotationManagerEnabledNumber) {
                        [documentController setAnnotationManagerEnabled:[annotationManagerEnabledNumber boolValue]];
                    }
                }
                else if ([key isEqualToString:PTUserIdKey])
                {
                    NSString* userId = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTUserIdKey class:[NSString class] error:&error];
                    
                    if (!error && userId) {
                        [documentController setUserId:userId];
                    }
                }
                else if ([key isEqualToString:PTUserNameKey])
                {
                    NSString* userName = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTUserNameKey class:[NSString class] error:&error];
                    
                    if (!error && userName) {
                        [documentController setUserName:userName];
                    }
                }
                else if ([key isEqualToString:PTAnnotationManagerEditModeKey])
                {
                    NSString *editMode = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTAnnotationManagerEditModeKey class:[NSString class] error:&error];
                    
                    if (!error && editMode) {
                        documentController.annotationManagerEditMode = [editMode copy];
                    }
                }
                else if ([key isEqualToString:PTAnnotationManagerUndoModeKey])
                {
                    NSString *undoMode = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTAnnotationManagerUndoModeKey class:[NSString class] error:&error];
                    
                    if (!error && undoMode) {
                        documentController.annotationManagerUndoMode = [undoMode copy];
                    }
                }
                else if ([key isEqualToString:PTAnnotationToolbarAlignmentKey])
                {
                    NSString *alignmentString = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTAnnotationToolbarAlignmentKey class:[NSString class] error:&error];

                    if (!error && alignmentString) {
                        if ([alignmentString isEqualToString:PTAnnotationToolbarAlignmentEndKey]) {
                            documentController.toolGroupToolbar.itemsAlignment = PTToolGroupToolbarAlignmentTrailing;
                        } else {
                            documentController.toolGroupToolbar.itemsAlignment = PTToolGroupToolbarAlignmentLeading;
                        }
                    }
                }
                else if ([key isEqualToString:PTHideScrollbarsKey])
                {
                    NSNumber* hideScrollbarsValue = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTHideScrollbarsKey class:[NSNumber class] error:&error];
                    
                    BOOL hideScrollbars = [hideScrollbarsValue boolValue];

                    if (!error && hideScrollbars) {
                        if (hideScrollbars) {
                            documentController.pdfViewCtrl.contentScrollView.showsHorizontalScrollIndicator = !hideScrollbars;
                            documentController.pdfViewCtrl.contentScrollView.showsVerticalScrollIndicator = !hideScrollbars;
                            
                            documentController.pdfViewCtrl.pagingScrollView.showsHorizontalScrollIndicator = !hideScrollbars;
                            documentController.pdfViewCtrl.pagingScrollView.showsVerticalScrollIndicator = !hideScrollbars;
                        }
                    }
                }
                else if([key isEqualToString:PTQuickBookmarkCreationKey])
                {
                    NSNumber* quickBookmarkCreation = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTQuickBookmarkCreationKey class:[NSNumber class] error:&error];

                    if (!error && quickBookmarkCreation) {
                        documentController.bookmarkPageButtonHidden = ![quickBookmarkCreation boolValue];
                    }
                }
                // Hygen Generated Configs
                else if ([key isEqualToString:PTMaxSignatureCountKey])
                {
                    NSNumber* maxSignatureCount = [PdftronFlutterPlugin getConfigValue:configPairs configKey:PTMaxSignatureCountKey class:[NSNumber class] error:&error];

                    if (!error && maxSignatureCount) {
                        documentController.toolManager.signatureAnnotationOptions.maxSignatureCount = [maxSignatureCount intValue];
                    }
                }
                else
                {
                    NSLog(@"Unknown JSON key in config: %@.", key);
                }
                
                if (error) {
                    NSLog(@"An error occurs with config %@: %@", key, error.localizedDescription);
                }
            }
        }
        else
        {
            NSLog(@"config JSON object not in expected dictionary format.");
        }
        

    }
    
    // Some iOS versions/devices may throw NSGenericException from internal UIKit layout
    // (ex: UISlider/PTResizingToolbar constraint issues). Catch to avoid hard crash.
    @try {
        [documentController applyViewerSettings];
    } @catch (NSException *exception) {
        NSLog(@"[PDFTRON iOS] Caught exception in applyViewerSettings: %@", exception.reason);
    }
}

+ (id)getConfigValue:(NSDictionary*)configDict configKey:(NSString*)configKey class:(Class)class error:(NSError**)error
{
    id configResult = configDict[configKey];

    if (![configResult isKindOfClass:[NSNull class]]) {
        if (![configResult isKindOfClass:class]) {
            NSString* errorString = [NSString stringWithFormat:@"config %@ is not in expected %@ format.", configKey, class];

            *error = [NSError errorWithDomain:@"com.flutter.pdftron" code:NSFormattingError userInfo:@{NSLocalizedDescriptionKey: errorString}];
        }
        return configResult;
    }
    return nil;
}

- (void)topLeftButtonPressed:(UIBarButtonItem *)barButtonItem
{
    if (!self.isWidgetView) {
        [self.tabbedDocumentViewController.navigationController dismissViewControllerAnimated:YES completion:nil];
    }
    
    [self documentController:[self getDocumentController] leadingNavButtonClicked:nil];
}

+ (void)disableTools:(NSArray<id> *)toolsToDisable documentController:(PTDocumentController *)documentController
{
    PTToolManager *toolManager = documentController.toolManager;
    
    for (id item in toolsToDisable) {
        BOOL value = NO;
        
        if ([item isKindOfClass:[NSString class]]) {
            NSString *string = (NSString *)item;
            
            if ([string isEqualToString:PTAnnotationEditToolKey] ||
                [string isEqualToString:PTEditToolButtonKey] ||
                [string isEqualToString:PTMultiSelectToolKey]) {
                toolManager.allowsMultipleAnnotationSelection = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateStickyToolKey] ||
                     [string isEqualToString:PTStickyToolButtonKey]) {
                toolManager.textAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateFreeHandToolKey] ||
                     [string isEqualToString:PTFreeHandToolButtonKey]) {
                toolManager.inkAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTTextSelectToolKey]) {
                toolManager.textSelectionEnabled = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateTextHighlightToolKey] ||
                     [string isEqualToString:PTHighlightToolButtonKey]) {
                toolManager.highlightAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateTextUnderlineToolKey] ||
                     [string isEqualToString:PTUnderlineToolButtonKey]) {
                toolManager.underlineAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateTextSquigglyToolKey] ||
                     [string isEqualToString:PTSquigglyToolButtonKey]) {
                toolManager.squigglyAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateTextStrikeoutToolKey] ||
                     [string isEqualToString:PTStrikeoutToolButtonKey]) {
                toolManager.strikeOutAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateFreeTextToolKey] ||
                     [string isEqualToString:PTFreeTextToolButtonKey]) {
                toolManager.freeTextAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateCalloutToolKey] ||
                     [string isEqualToString:PTCalloutToolButtonKey]) {
                toolManager.calloutAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateSignatureToolKey] ||
                     [string isEqualToString:PTSignatureToolButtonKey]) {
                toolManager.signatureAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateLineToolKey] ||
                     [string isEqualToString:PTLineToolButtonKey]) {
                toolManager.lineAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateArrowToolKey] ||
                     [string isEqualToString:PTArrowToolButtonKey]) {
                toolManager.arrowAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreatePolylineToolKey] ||
                     [string isEqualToString:PTPolylineToolButtonKey]) {
                toolManager.polylineAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateStampToolKey] ||
                     [string isEqualToString:PTStampToolButtonKey]) {
                toolManager.imageStampAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateRectangleToolKey] ||
                     [string isEqualToString:PTRectangleToolButtonKey]) {
                toolManager.squareAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateEllipseToolKey] ||
                     [string isEqualToString:PTEllipseToolButtonKey]) {
                toolManager.circleAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreatePolygonToolKey] ||
                     [string isEqualToString:PTPolygonToolButtonKey]) {
                toolManager.polygonAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreatePolygonCloudToolKey] ||
                     [string isEqualToString:PTCloudToolButtonKey])
            {
                toolManager.cloudyAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateFreeHighlighterToolKey] ||
                     [string isEqualToString:PTFreeHighlighterToolButtonKey]) {
                toolManager.freehandHighlightAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTEraserToolKey] ||
                     [string isEqualToString:PTEraserToolButtonKey]) {
                toolManager.eraserEnabled = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateFileAttachmentToolKey]) {
                toolManager.fileAttachmentAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateRedactionToolKey]) {
                toolManager.redactAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateLinkToolKey]) {
                toolManager.linkAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateDistanceMeasurementToolKey]) {
                toolManager.rulerAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreatePerimeterMeasurementToolKey]) {
                toolManager.perimeterAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateAreaMeasurementToolKey]) {
                toolManager.areaAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateRubberStampToolKey]) {
                toolManager.stampAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationCreateRedactionTextToolKey]) {
                // TODO
            }
            else if ([string isEqualToString:PTAnnotationCreateLinkTextToolKey]) {
                toolManager.linkAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTFormCreateTextFieldToolKey]) {
                // TODO
            }
            else if ([string isEqualToString:PTFormCreateCheckboxFieldToolKey]) {
                // TODO
            }
            else if ([string isEqualToString:PTFormCreateSignatureFieldToolKey]) {
                // TODO
            }
            else if ([string isEqualToString:PTFormCreateRadioFieldToolKey]) {
                // TODO
            }
            else if ([string isEqualToString:PTFormCreateComboBoxFieldToolKey]) {
                // TODO
            }
            else if ([string isEqualToString:PTFormCreateListBoxFieldToolKey]) {
                // TODO
            }
            else if ([string isEqualToString:PTAnnotationCreateFreeHighlighterToolKey]) {
                toolManager.freehandHighlightAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTPencilKitDrawingToolKey]) {
                toolManager.pencilDrawingAnnotationOptions.canCreate = value;
            }
            else if ([string isEqualToString:PTAnnotationSmartPenToolKey]) {
                toolManager.smartPenEnabled = value;
            }
        }
    }
}

+ (void)disableElements:(NSArray*)elementsToDisable documentController:(PTDocumentController *)documentController
{
    typedef void (^HideElementBlock)(void);
    
    NSDictionary *hideElementActions = @{
        PTToolsButtonKey:
            ^{
//                TODO: unsupported: documentController.annotationToolbarButtonHidden = YES;
            },
        PTSearchButtonKey:
            ^{
                documentController.searchButtonHidden = YES;
            },
        PTShareButtonKey:
            ^{
                documentController.shareButtonHidden = YES;
            },
        PTViewControlsButtonKey:
            ^{
                documentController.viewerSettingsButtonHidden = YES;
            },
        PTThumbnailsButtonKey:
            ^{
                documentController.thumbnailBrowserButtonHidden = YES;
            },
        PTListsButtonKey:
            ^{
                documentController.navigationListsButtonHidden = YES;
            },
        PTReflowModeButtonKey:
            ^{
                documentController.readerModeButtonHidden = YES;
                documentController.settingsViewController.viewModeReaderHidden = YES;
            },
        PTThumbnailSliderKey:
            ^{
                documentController.thumbnailSliderHidden = YES;
            },
        PTSaveCopyButtonKey:
            ^{
                documentController.exportButtonHidden = YES;
            },
        PTEditPagesButtonKey:
            ^{
                documentController.addPagesButtonHidden = YES;
            },
//        PTPrintButtonKey:
//            ^{
//
//            },
//        PTCloseButtonKey:
//            ^{
//
//            },
//        PTFillAndSignButtonKey:
//            ^{
//
//            },
//        PTPrepareFormButtonKey:
//            ^{
//
//            },
        PTOutlineListButtonKey:
            ^{
                documentController.outlineListHidden = YES;
            },
        PTAnnotationListButtonKey:
            ^{
                documentController.annotationListHidden = YES;
            },
        PTUserBookmarkListButtonKey:
            ^{
                documentController.bookmarkListHidden = YES;
            },
        PTLayerListButtonKey:
            ^{
                documentController.pdfLayerListHidden = YES;
                documentController.navigationListsViewController.pdfLayerViewControllerVisibility = PTNavigationListsViewControllerVisibilityAlwaysHidden;
            },
        PTEditMenuButtonKey:
            ^{
                documentController.toolGroupManager.editingEnabled = NO;
            },
        PTCropPageButtonKey:
            ^{
                documentController.settingsViewController.cropPagesHidden = YES;
            },
        PTUndoKey:
            ^{
                documentController.toolGroupToolbar.automaticallyUpdatesTrailingItems = NO;
                documentController.toolGroupToolbar.trailingItems = nil;
            },
        PTRedoKey:
            ^{
                documentController.toolGroupToolbar.automaticallyUpdatesTrailingItems = NO;
                documentController.toolGroupToolbar.trailingItems = nil;
            },
        PTMoreItemsButtonKey:
            ^{
                documentController.moreItemsButtonHidden = YES;
            },
        PTSaveIdenticalCopyButtonKey:
            ^ {
                if (![documentController isExportButtonHidden]) {
                    NSMutableArray * exportItems = [documentController.exportItems mutableCopy];
                    [exportItems removeObject:documentController.exportCopyButtonItem];
                    documentController.exportItems = [exportItems copy];
                }
            },
        PTSaveFlattenedCopyButtonKey:
            ^{
                if (![documentController isExportButtonHidden]) {
                    NSMutableArray * exportItems = [documentController.exportItems mutableCopy];
                    [exportItems removeObject:documentController.exportFlattenedCopyButtonItem];
                    documentController.exportItems = [exportItems copy];
                }
            },
        PTSaveCroppedCopyButtonKey:
            ^{
                if (![documentController isExportButtonHidden]) {
                    NSMutableArray * exportItems = [documentController.exportItems mutableCopy];
                    [exportItems removeObject:documentController.exportCroppedCopyButtonItem];
                    documentController.exportItems = [exportItems copy];
                }
            },
        PTSaveReducedCopyButtonKey:
            ^{
                if (![documentController isExportButtonHidden]) {
                    NSMutableArray * exportItems = [documentController.exportItems mutableCopy];
                    [exportItems removeObject:documentController.exportReducedFileSizeCopyButtonItem];
                    documentController.exportItems = [exportItems copy];
                }
            },
    };
    
    for(NSObject* item in elementsToDisable)
    {
        if([item isKindOfClass:[NSString class]])
        {
            HideElementBlock block = hideElementActions[item];
            if (block)
            {
                block();
            }
        }
    }
    
    [self disableTools:elementsToDisable documentController:documentController];
}

#pragma mark - PTTabbedDocumentViewControllerDelegate

- (void)tabbedDocumentViewController:(PTTabbedDocumentViewController *)tabbedDocumentViewController willAddDocumentViewController:(PTFlutterDocumentController *)documentController
{
    documentController.delegate = self;
    documentController.plugin = self;
    
    if (self.config && documentController.isDocCtrlrConfigured == NO) {
        [[self class] configureDocumentController:documentController
                                           withConfig:self.config];
        documentController.docCtrlrConfigured = YES;
    }
}

- (BOOL)tabbedDocumentViewController:(PTTabbedDocumentViewController *)tabbedDocumentViewController shouldHideTabBarForTraitCollection:(UITraitCollection *)traitCollection
{
    // Always show tab bar when enabled, regardless of the trait collection.
    return NO;
}

#pragma mark - PTDocumentControllerDelegate

- (void)documentControllerDidOpenDocument:(PTDocumentController *)documentController
{
    NSLog(@"Document opened successfully");
    FlutterResult result = ((PTFlutterDocumentController*)documentController).openResult;
    if (result) {
        result(@"Opened Document Successfully");
    }
}

- (void)documentController:(PTDocumentController *)documentController didFailToOpenDocumentWithError:(NSError *)error
{
    NSLog(@"Failed to open document: %@", error);
    FlutterResult result = ((PTFlutterDocumentController*)documentController).openResult;
    [self documentController:documentController documentError:nil];
    if (result) {
        result([@"Opened Document Failed: %@" stringByAppendingString:error.description]);
    } 
}

#pragma mark - FlutterStreamHandler

- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments eventSink:(FlutterEventSink)events
{
    
    int sinkId = [arguments intValue];
    
    switch (sinkId)
    {
        case exportAnnotationId:
            self.xfdfEventSink = events;
            break;
        case exportBookmarkId:
            self.bookmarkEventSink = events;
            break;
        case documentLoadedId:
            self.documentLoadedEventSink = events;
            break;
        case documentErrorId:
            self.documentErrorEventSink = events;
            break;
        case annotationChangedId:
            self.annotationChangedEventSink = events;
            break;
        case annotationsSelectedId:
            self.annotationsSelectedEventSink = events;
            break;
        case formFieldValueChangedId:
            self.formFieldValueChangedEventSink = events;
            break;
        case behaviorActivatedId:
            self.behaviorActivatedEventSink = events;
            break;
        case longPressMenuPressedId:
            self.longPressMenuPressedEventSink = events;
            break;
        case annotationMenuPressedId:
            self.annotationMenuPressedEventSink = events;
            break;
        case leadingNavButtonPressedId:
            self.leadingNavButtonPressedEventSink = events;
            break;
        case pageChangedId:
            self.pageChangedEventSink = events;
            break;
        case zoomChangedId:
            self.zoomChangedEventSink = events;
            break;
        case pageMovedId:
            self.pageMovedEventSink = events;
            break;
        case scrollChangedId:
            self.scrollChangedEventSink = events;
            break;
        // Hygen Generated Event Listeners (3)
        case annotationToolbarItemPressedId:
            self.annotationToolbarItemPressedEventSink = events;
            break;
        case appBarButtonPressedId:
            self.appBarButtonPressedEventSink = events;
            break;
        case bauhubPolygonStateId:
            [BauhubPolygonMarkupTool setStateEventSink:events];
            break;
    }
    
    return Nil;
}

- (FlutterError* _Nullable)onCancelWithArguments:(id _Nullable)arguments
{
    int sinkId = [arguments intValue];
    
    switch (sinkId)
    {
        case exportAnnotationId:
            self.xfdfEventSink = nil;
            break;
        case exportBookmarkId:
            self.bookmarkEventSink = nil;
            break;
        case documentLoadedId:
            self.documentLoadedEventSink = nil;
            break;
        case documentErrorId:
            self.documentErrorEventSink = nil;
            break;
        case annotationChangedId:
            self.annotationChangedEventSink = nil;
            break;
        case annotationsSelectedId:
            self.annotationsSelectedEventSink = nil;
            break;
        case formFieldValueChangedId:
            self.formFieldValueChangedEventSink = nil;
            break;
        case behaviorActivatedId:
            self.behaviorActivatedEventSink = nil;
            break;
        case longPressMenuPressedId:
            self.longPressMenuPressedEventSink = nil;
            break;
        case annotationMenuPressedId:
            self.annotationMenuPressedEventSink = nil;
            break;
        case leadingNavButtonPressedId:
            self.leadingNavButtonPressedEventSink = nil;
            break;
        case pageChangedId:
            self.pageChangedEventSink = nil;
            break;
        case zoomChangedId:
            self.zoomChangedEventSink = nil;
            break;
        case pageMovedId:
            self.pageMovedEventSink = nil;
            break;
        case scrollChangedId:
            self.scrollChangedEventSink = nil;
            break;
        // Hygen Generated Event Listeners (4)
        case annotationToolbarItemPressedId:
            self.annotationToolbarItemPressedEventSink = nil;
            break;
        case appBarButtonPressedId:
            self.appBarButtonPressedEventSink = nil;
            break;
        case bauhubPolygonStateId:
            [BauhubPolygonMarkupTool setStateEventSink:nil];
            break;
    }
    
    return Nil;
}

#pragma mark - FlutterPlatformView

-(UIView*)view
{
    // Note: this will only be called if it is the widget version
    return self.tabbedDocumentViewController.navigationController.view;
}

#pragma mark - Cleanup

-(void)dealloc
{
    if (self.isWidgetView)
    {
        [self.tabbedDocumentViewController.navigationController willMoveToParentViewController:nil];
        [self.tabbedDocumentViewController.navigationController removeFromParentViewController];
    }
}

#pragma mark - EventSinks

-(void)documentController:(PTDocumentController*)documentController bookmarksDidChange:(NSString*)bookmarkJson
{
    if(self.bookmarkEventSink != nil)
    {
        self.bookmarkEventSink(bookmarkJson);
    }
}

-(void)documentController:(PTDocumentController*)documentController annotationsAsXFDFCommand:(NSString*)xfdfCommand
{
    if(self.xfdfEventSink != nil)
    {
        NSString *normalized = BauhubNormalizeBauhubAreaMarkupXfdfForWebParity(xfdfCommand);
        self.xfdfEventSink(normalized);
    }
}

-(void)documentController:(PTDocumentController*)documentController documentLoadedFromFilePath:(NSString*)filePath
{
    if(self.documentLoadedEventSink != nil)
    {
        self.documentLoadedEventSink(filePath);
    }
}

-(void)documentController:(PTDocumentController*)documentController documentError:(nullable NSError*)error
{
    if(self.documentErrorEventSink != nil)
    {
        self.documentErrorEventSink(nil);
    }
}

-(void)documentController:(PTDocumentController*)documentController annotationsChangedWithActionString:(NSString*)annotationsWithActionString
{
    if(self.annotationChangedEventSink != nil)
    {
        self.annotationChangedEventSink(annotationsWithActionString);
    }
}

-(void)documentController:(PTDocumentController*)documentController annotationsSelected:(NSString*)annotationsString
{
    if(self.annotationsSelectedEventSink != nil)
    {
        self.annotationsSelectedEventSink(annotationsString);
    }
}

-(void)documentController:(PTDocumentController*)documentController formFieldValueChanged:(NSString*)fieldsString
{
    if(self.formFieldValueChangedEventSink != nil)
    {
        self.formFieldValueChangedEventSink(fieldsString);
    }
}

-(void)documentController:(PTDocumentViewController*)docVC behaviorActivated:(NSString*)behaviorString
{
    if(self.behaviorActivatedEventSink != nil)
    {
        self.behaviorActivatedEventSink(behaviorString);
    }
}

-(void)documentController:(PTDocumentController*)docVC longPressMenuPressed:(NSString*)longPressMenuPressedString
{
    if (self.longPressMenuPressedEventSink != nil)
    {
        self.longPressMenuPressedEventSink(longPressMenuPressedString);
    }
}

-(void)documentController:(PTDocumentController *)docVC annotationMenuPressed:(NSString*)annotationMenuPressedString
{
    if (self.annotationMenuPressedEventSink != nil)
    {
        self.annotationMenuPressedEventSink(annotationMenuPressedString);
    }
}
    
-(void)documentController:(PTDocumentController *)docVC leadingNavButtonClicked:(nullable NSString *)nav
{
    if (self.leadingNavButtonPressedEventSink != nil)
    {
        self.leadingNavButtonPressedEventSink(nil);
    }
}

-(void)documentController:(PTDocumentController *)docVC pageChanged:(NSString*)pageNumbersString
{
    if (self.pageChangedEventSink != nil)
    {
        self.pageChangedEventSink(pageNumbersString);
    }
}

-(void)documentController:(PTDocumentController *)docVC zoomChanged:(NSNumber*)zoom
{
    if (self.zoomChangedEventSink != nil)
    {
        self.zoomChangedEventSink(zoom);
    }
    BauhubScheduleDecorativeAreaPinZoomSync(docVC.pdfViewCtrl);
}

-(void)documentController:(PTDocumentController *)docVC pageMoved:(NSString *)pageNumbersString
{
    if (self.pageMovedEventSink != nil)
    {
        self.pageMovedEventSink(pageNumbersString);
    }
}

-(void)documentController:(PTDocumentController *)docVC scrollChanged:(NSString *)scrollString
{
    PTPDFViewCtrl *pdfViewCtrl = docVC.pdfViewCtrl;
    
    double horizontal = [pdfViewCtrl GetHScrollPos];
    double vertical = [pdfViewCtrl GetVScrollPos];

     NSDictionary *resultDict = @{
         PTReflowOrientationHorizontalKey: [NSNumber numberWithDouble:horizontal],
         PTReflowOrientationVerticalKey: [NSNumber numberWithDouble:vertical],
    };

    if (self.scrollChangedEventSink != nil)
    {
        self.scrollChangedEventSink([PdftronFlutterPlugin PT_idToJSONString:resultDict]);
    }
}

// Hygen Generated Event Listeners (5)
- (void)documentController:(PTDocumentController *)docVC annotationToolbarItemPressed:(NSString *)annotationToolbarItemPressedString
{
    
    if (self.annotationToolbarItemPressedEventSink != nil)
    {
        self.annotationToolbarItemPressedEventSink(annotationToolbarItemPressedString);
    }
}
- (void)documentController:(PTDocumentController *)docVC appBarButtonPressed:(NSString *)appBarButtonPressedString
{
    if (self.appBarButtonPressedEventSink != nil)
    {
        self.appBarButtonPressedEventSink(appBarButtonPressedString);
    }
}


#pragma mark - Functions

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([call.method isEqualToString:PTGetPlatformVersionKey]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([call.method isEqualToString:PTSetCustomDataForAnnotationKey]) {
        NSString *annotation = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTAnnotationArgumentKey]];
        NSArray *fieldNames = [PdftronFlutterPlugin PT_idAsArray:call.arguments[PTFieldNamesArgumentKey]];
        [self setCustomDataForAnnotation:annotation fieldNames:fieldNames resultToken:result];
    } else if ([call.method isEqualToString:PTIsBauhubToolModeKey]) {
        [self isBauhubToolMode:result];
    } else if ([call.method isEqualToString:PTHideAnnotationKey]) {
        NSString *annotation = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTAnnotationArgumentKey]];
        [self hideAnnotation:annotation resultToken:result];
    } else if ([call.method isEqualToString:PTHideAllAnnotationsKey]) {
        NSNumber *pageNumber = [PdftronFlutterPlugin PT_idAsNSNumber:call.arguments[PTPageNumberArgumentKey]];
        [self hideAllAnnotations:pageNumber resultToken:result];
    } else if ([call.method isEqualToString:PTShowAnnotationKey]) {
        NSString *annotation = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTAnnotationArgumentKey]];
        [self showAnnotation:annotation resultToken:result];
    } else if ([call.method isEqualToString:PTGetVersionKey]) {
        result([@"PDFNet " stringByAppendingFormat:@"%f", [PTPDFNet GetVersion]]);
    } else if ([call.method isEqualToString:PTInitializeKey]) {
        NSString *licenseKey = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTLicenseArgumentKey]];
        [PTPDFNet Initialize:licenseKey];
    } else if ([call.method isEqualToString:PTOpenDocumentKey]) {
        [self handleOpenDocumentMethod:call.arguments resultToken:result];
    } else if ([call.method isEqualToString:PTImportAnnotationsKey]) {
        NSString *xfdf = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTXfdfArgumentKey]];;
        [self importAnnotations:xfdf resultToken:result];
    } else if ([call.method isEqualToString:PTMergeAnnotationsKey]) {
        NSString *xfdf = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTXfdfArgumentKey]];;
        [self mergeAnnotations:xfdf resultToken:result];
    } else if ([call.method isEqualToString:PTExportAnnotationsKey]) {
        NSString *annotationList = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTAnnotationListArgumentKey]];;
        [self exportAnnotations:annotationList resultToken:result];
    } else if ([call.method isEqualToString:PTFlattenAnnotationsKey]) {
        bool formsOnly = [PdftronFlutterPlugin PT_idAsBool:call.arguments[PTFormsOnlyArgumentKey]];
        [self flattenAnnotations:formsOnly resultToken:result];
    } else if ([call.method isEqualToString:PTDeleteAnnotationsKey]) {
        NSString *annotationList = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTAnnotationListArgumentKey]];;
        [self deleteAnnotations:annotationList resultToken:result];
    } else if ([call.method isEqualToString:PTSelectAnnotationKey]) {
        NSString *annotation = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTAnnotationArgumentKey]];
        [self selectAnnotation:annotation resultToken:result];
    } else if ([call.method isEqualToString:PTSetFlagsForAnnotationsKey]) {
        NSString *annotationsWithFlags = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTAnnotationsWithFlagsArgumentKey]];
        [self setFlagsForAnnotations:annotationsWithFlags resultToken:result];
    } else if ([call.method isEqualToString:PTSetPropertiesForAnnotationKey]) {
        NSString *annotation = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTAnnotationArgumentKey]];
        NSString *properties = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTAnnotationPropertiesArgumentKey]];
        [self setPropertiesForAnnotation:annotation properties:properties resultToken:result];
    } else if ([call.method isEqualToString:PTGroupAnnotationsKey]) {
        NSString *primaryAnnotation = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTAnnotationArgumentKey]];
        NSString *subAnnotations = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTAnnotationListArgumentKey]];
        [self groupAnnotations:primaryAnnotation subAnnotations:subAnnotations resultToken:result];
    } else if ([call.method isEqualToString:PTUngroupAnnotationsKey]) {
        NSString *annotations = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTAnnotationListArgumentKey]];
        [self ungroupAnnotations:annotations resultToken:result];
    } else if ([call.method isEqualToString:PTImportAnnotationCommandKey]) {
        NSString *xfdfCommand = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTXfdfCommandArgumentKey]];
        [self importAnnotationCommand:xfdfCommand resultToken:result];
    } else if ([call.method isEqualToString:PTImportBookmarksKey]) {
        NSString *bookmarkJson = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTBookmarkJsonArgumentKey]];
        [self importBookmarks:bookmarkJson resultToken:result];
    } else if ([call.method isEqualToString:PTAddBookmarkKey]) {
        NSString *title = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTBookmarkTitleArgumentKey]];
        NSNumber *pageNumber = [PdftronFlutterPlugin PT_idAsNSNumber:call.arguments[PTPageNumberArgumentKey]];
        [self addBookmark:title pageNumber:pageNumber resultToken:result];
    } else if ([call.method isEqualToString:PTSaveDocumentKey]) {
        [self saveDocument:result];
    } else if ([call.method isEqualToString:PTCommitToolKey]) {
        [self commitTool:result];
    } else if ([call.method isEqualToString:PTGetPageCountKey]) {
        [self getPageCount:result];
    } else if ([call.method isEqualToString:PTUndoKey]) {
        [self undo:result];
    } else if ([call.method isEqualToString:PTRedoKey]) {
        [self redo:result];
    } else if ([call.method isEqualToString:PTCanUndoKey]) {
        [self canUndo:result];
    } else if ([call.method isEqualToString:PTCanRedoKey]) {
        [self canRedo:result];
    } else if ([call.method isEqualToString:PTGetPageCropBoxKey]) {
        NSNumber *pageNumber = [PdftronFlutterPlugin PT_idAsNSNumber:call.arguments[PTPageNumberArgumentKey]];
        [self getPageCropBox:pageNumber resultToken:result];
    } else if ([call.method isEqualToString:PTGetPageRotationKey]) {
        NSNumber *pageNumber = [PdftronFlutterPlugin PT_idAsNSNumber:call.arguments[PTPageNumberArgumentKey]];
        [self getPageRotation:pageNumber resultToken:result];
    } else if ([call.method isEqualToString:PTRotateClockwiseKey]) {
        [self rotateClockwise:result];
    } else if ([call.method isEqualToString:PTRotateCounterClockwiseKey]) {
        [self rotateCounterClockwise:result];
    } else if ([call.method isEqualToString:PTSetCurrentPageKey]) {
        NSNumber* pageNumber = [PdftronFlutterPlugin PT_idAsNSNumber:call.arguments[PTPageNumberArgumentKey]];
        [self setCurrentPage:pageNumber resultToken:result];
    } else if ([call.method isEqualToString:PTGotoPreviousPageKey]) {
        [self gotoPreviousPage:result];
    } else if ([call.method isEqualToString:PTGotoNextPageKey]) {
        [self gotoNextPage:result];
    } else if ([call.method isEqualToString:PTGotoFirstPageKey]) {
        [self gotoFirstPage:result];
    } else if ([call.method isEqualToString:PTGotoLastPageKey]) {
        [self gotoLastPage:result];

    } else if ([call.method isEqualToString:PTGetDocumentPathKey]) {
        [self getDocumentPath:result];
    } else if ([call.method isEqualToString:PTSetToolModeKey]) {
           NSString *toolMode = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTToolModeArgumentKey]];
           [self setToolMode:toolMode resultToken:result];
    } else if ([call.method isEqualToString:PTSetBauhubAreaMarkupColorsKey]) {
        NSDictionary *colorArgs = [PdftronFlutterPlugin PT_idAsNSDict:call.arguments];
        if (!colorArgs && [call.arguments isKindOfClass:[NSDictionary class]]) {
            colorArgs = (NSDictionary *)call.arguments;
        }
        if (colorArgs) {
            NSUInteger fillArgb = 0;
            NSUInteger strokeArgb = 0;
            if (BauhubTryUint32FromFlutterColorArg(colorArgs[PTFillColorArgbArgumentKey], &fillArgb) &&
                BauhubTryUint32FromFlutterColorArg(colorArgs[PTStrokeColorArgbArgumentKey], &strokeArgb)) {
                BauhubSetAreaMarkupPresetColors((unsigned)fillArgb, (unsigned)strokeArgb);
                PTDocumentController *dc = [self getDocumentController];
                if (dc.pdfViewCtrl) {
                    BauhubApplyAreaToolDrawPreviewDefaults(dc.pdfViewCtrl);
                }
            }
        }
        result(nil);
    } else if ([call.method isEqualToString:PTBauhubCancelActiveShapeKey]) {
        PTDocumentController *dc = [self getDocumentController];
        result(@([BauhubPolygonMarkupTool cancelActiveShapeWithToolManager:dc.toolManager]));
    } else if ([call.method isEqualToString:PTBauhubUndoActiveShapePointKey]) {
        PTDocumentController *dc = [self getDocumentController];
        result(@([BauhubPolygonMarkupTool undoActiveShapePointWithToolManager:dc.toolManager]));
    } else if ([call.method isEqualToString:PTBauhubRedoActiveShapePointKey]) {
        PTDocumentController *dc = [self getDocumentController];
        result(@([BauhubPolygonMarkupTool redoActiveShapePointWithToolManager:dc.toolManager]));
    } else if ([call.method isEqualToString:PTSetFlagForFieldsKey]) {
        NSArray *fieldNames = [PdftronFlutterPlugin PT_idAsArray:call.arguments[PTFieldNamesArgumentKey]];
        NSNumber *flag = [PdftronFlutterPlugin PT_idAsNSNumber:call.arguments[PTFlagArgumentKey]];
        bool flagValue = [[PdftronFlutterPlugin PT_idAsNSNumber:call.arguments[PTFlagValueArgumentKey]] boolValue];
        [self setFlagForFields:fieldNames flag:flag flagValue:flagValue resultToken:result];
    } else if ([call.method isEqualToString:PTSetValuesForFieldsKey]) {
        NSString *fieldWithValuesString = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTFieldsArgumentKey]];
        [self setValuesForFields:fieldWithValuesString resultToken:result];
    } else if ([call.method isEqualToString:PTSetLeadingNavButtonIconKey]) {
        NSString* leadingNavButtonIcon = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTLeadingNavButtonIconArgumentKey]];
        [self setLeadingNavButtonIcon:leadingNavButtonIcon resultToken:result];
    } else if ([call.method isEqualToString:PTCloseAllTabsKey]) {
        [self closeAllTabs:result];
    } else if ([call.method isEqualToString:PTDeleteAllAnnotationsKey]) {
        [self deleteAllAnnotations:result];
    } else if ([call.method isEqualToString:PTExportAsImageKey]) {
        NSNumber* pageNumber = [PdftronFlutterPlugin PT_idAsNSNumber:call.arguments[PTPageNumberArgumentKey]];
        NSNumber* dpi = [PdftronFlutterPlugin PT_idAsNSNumber:call.arguments[PTDpiArgumentKey]];
        NSString* exportFormat = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTExportFormatArgumentKey]];
        [self exportAsImage:pageNumber dpi:dpi exportFormat:exportFormat filePath:Nil resultToken:result];
    } else if ([call.method isEqualToString:PTExportAsImageFromFilePathKey]) {
        NSNumber* pageNumber = [PdftronFlutterPlugin PT_idAsNSNumber:call.arguments[PTPageNumberArgumentKey]];
        NSNumber* dpi = [PdftronFlutterPlugin PT_idAsNSNumber:call.arguments[PTDpiArgumentKey]];
        NSString* exportFormat = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTExportFormatArgumentKey]];
        NSString* filePath = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTPathArgumentKey]];
        [self exportAsImage:pageNumber dpi:dpi exportFormat:exportFormat filePath:filePath resultToken:result];
    } else if ([call.method isEqualToString:PTOpenAnnotationListKey]) {
        [self openAnnotationList:result];
    } else if ([call.method isEqualToString:PTOpenBookmarkListKey]) {
        [self openBookmarkList:result];
    } else if ([call.method isEqualToString:PTOpenOutlineListKey]) {
        [self openOutlineList:result];
    } else if ([call.method isEqualToString:PTOpenLayersListKey]) {
        [self openLayersList:result];
    } else if ([call.method isEqualToString:PTOpenThumbnailsViewKey]) {
        [self openThumbnailsView:result];
    } else if ([call.method isEqualToString:PTOpenAddPagesViewKey]) {
        NSDictionary* rect = [PdftronFlutterPlugin PT_idAsNSDict:call.arguments[PTSourceRectArgumentKey]];
        [self openAddPagesView:result rect:rect];
    } else if ([call.method isEqualToString:PTOpenViewSettingsKey]) {
        NSDictionary* rect = [PdftronFlutterPlugin PT_idAsNSDict:call.arguments[PTSourceRectArgumentKey]];
        [self openViewSettings:result rect:rect];
    } else if ([call.method isEqualToString:PTOpenCropKey]) {
        [self openCrop:result];
    } else if ([call.method isEqualToString:PTOpenManualCropKey]) {
        [self openManualCrop:result];
    } else if ([call.method isEqualToString:PTOpenSearchKey]) {
        [self openSearch:result];
    } else if ([call.method isEqualToString:PTOpenTabSwitcherKey]) {
        [self openTabSwitcher:result];
    } else if ([call.method isEqualToString:PTOpenGoToPageViewKey]) {
        [self openGoToPageView:result];
    } else if ([call.method isEqualToString:PTOpenNavigationListsKey]) {
        [self openNavigationLists:result];
    } else if ([call.method isEqualToString:PTGetCurrentPageKey]) {
        [self getCurrentPage:result];
    } else if ([call.method isEqualToString:PTStartSearchModeKey]) {
        NSString* searchString = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTSearchStringArgumentKey]];
        bool matchCase = [PdftronFlutterPlugin PT_idAsBool:call.arguments[PTMatchCaseArgumentKey]];
        bool matchWholeWord = [PdftronFlutterPlugin PT_idAsBool:call.arguments[PTMatchWholeWordArgumentKey]];
        [self startSearchMode:searchString matchCase:matchCase matchWholeWord:matchWholeWord resultToken:result];
    } else if ([call.method isEqualToString:PTExitSearchModeKey]) {
        [self exitSearchMode:result];
    } else if ([call.method isEqualToString:PTZoomWithCenterKey]) {
        [self zoomWithCenter:result call:call];
    } else if ([call.method isEqualToString:PTZoomToRectKey]) {
        [self zoomToRect:result call:call];
    } else if ([call.method isEqualToString:PTGetZoomKey]) {
        [self getZoom:result];
    } else if ([call.method isEqualToString:PTSetZoomLimitsKey]) {
        [self setZoomLimits:result call:call];
    } else if ([call.method isEqualToString:PTGetSavedSignaturesKey]) {
        [self getSavedSignatures:result];
    } else if ([call.method isEqualToString:PTGetSavedSignatureFolderKey]) {
        [self getSavedSignatureFolder:result];
    } else if ([call.method isEqualToString:PTSetBackgroundColorKey]) {
        [self setBackgroundColor:result call:call];
    } else if ([call.method isEqualToString:PTSetDefaultPageColorKey]) {
        [self setDefaultPageColor:result call:call];
    } else if ([call.method isEqualToString:PTGetScrollPosKey]) {
        [self getScrollPos:result];
    } else if ([call.method isEqualToString:PTSetHorizontalScrollPositionKey]) {
        [self setHorizontalScrollPosition:call result:result];
    } else if ([call.method isEqualToString:PTSetVerticalScrollPositionKey]) {
        [self setVerticalScrollPosition:call result:result];
    } else if ([call.method isEqualToString:PTSmartZoomKey]) {
        [self smartZoom:result call:call];
    }
    // Hygen Generated Method Call Cases
    else if ([call.method isEqualToString:PTSetLayoutModeKey]) {
        [self setLayoutMode:result call:call];
    }
    else if ([call.method isEqualToString:PTSetFitModeKey]) {
        [self setFitMode:result call:call];
    }
    else if ([call.method isEqualToString:PTGetAnnotationsOnPageKey]) {
        [self getAnnotationsOnPage:result call:call];
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)setCustomDataForAnnotation:(NSString *)annotation fieldNames:(NSArray <NSString *> *)fieldNames resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        
        flutterResult([FlutterError errorWithCode:@"set_custom_data_for_annotation" message:@"Failed to set custom data" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    NSDictionary *annotationJson = [PdftronFlutterPlugin PT_idAsNSDict:[PdftronFlutterPlugin PT_JSONStringToId:annotation]];
    NSString *annotId = [PdftronFlutterPlugin PT_idAsNSString:annotationJson[PTAnnotIdKey]];
    int pageNumber = [[PdftronFlutterPlugin PT_idAsNSNumber:annotationJson[PTAnnotPageNumberKey]] intValue];
    NSError* error;
    PTAnnot *annot = [PdftronFlutterPlugin findAnnotWithUniqueID:annotId onPageNumber:pageNumber documentController:documentController error:&error];

    if (error) {
        NSLog(@"Error: Failed to find annotation with unique id. %@", error.localizedDescription);
        
        flutterResult([FlutterError errorWithCode:@"set_custom_data_for_annotation" message:@"Failed to select annotations" details:@"Error: Failed to find annotation with unique id."]);
        return;
    }
    
    [documentController.pdfViewCtrl DocLockReadWithBlock:^(PTPDFDoc * _Nullable doc) {
        int i;
        NSString *key;
        for (i = 0; i < [fieldNames count]; i++) {
            if (i % 2) {
                NSString *value = [fieldNames objectAtIndex:i];
                [annot SetCustomData:key value:value];
            } else {
                key = [fieldNames objectAtIndex:i];
            }
        }
    } error:&error];
    
    if (error) {
        NSLog(@"Error: Failed to set custom data. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"set_custom_data_for_annotation" message:@"Failed to select annotations" details:@"Error: Failed to select annotation from doc."]);
    } else {
        flutterResult(nil);
    }
}

- (void)isBauhubToolMode:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"get_tool_mode" message:@"Failed to get toolmode" details:@"Error: The document view controller has no document."]);
        return;
    }

    PTTool *tool = documentController.toolManager.tool;
    if ([tool isKindOfClass:[BauhubTaskTool class]]) {
        flutterResult(@"true");
        return;
    }
    flutterResult(@"false");
}

+ (PTAnnot *)findAnnotWithUniqueID:(NSString *)uniqueID onPageNumber:(int)pageNumber documentController:(PTDocumentController *)documentController error:(NSError **)error
{
    if (uniqueID.length == 0 || pageNumber < 1) {
        return nil;
    }
    PTPDFViewCtrl *pdfViewCtrl = documentController.pdfViewCtrl;
    __block PTAnnot *resultAnnot;

    [documentController.pdfViewCtrl DocLockReadWithBlock:^(PTPDFDoc * _Nullable doc) {
        NSArray<PTAnnot *> *annots = [pdfViewCtrl GetAnnotationsOnPage:pageNumber];
        for (PTAnnot *annot in annots) {
            if (![annot IsValid]) {
                continue;
            }
            
            // Check if the annot's unique ID matches.
            NSString *annotUniqueId = nil;
            PTObj *annotUniqueIdObj = [annot GetUniqueID];
            if ([annotUniqueIdObj IsValid]) {
                annotUniqueId = [annotUniqueIdObj GetAsPDFText];
            }
            if (annotUniqueId && [annotUniqueId isEqualToString:uniqueID]) {
                resultAnnot = annot;
                break;
            }
        }
    } error:error];
   
    if(*error)
    {
        NSLog(@"Error: There was an error while trying to find annotation with id and page number. %@", (*error).localizedDescription);
    }
    
    return resultAnnot;
}

+(NSArray<PTAnnot *> *)getAnnotationsOnPage:(int)pageNumber documentController:(PTDocumentController *)documentController
{
    __block NSArray<PTAnnot *> *annots;
    NSError* error;
    [documentController.pdfViewCtrl DocLockReadWithBlock:^(PTPDFDoc * _Nullable doc) {
        annots = [documentController.pdfViewCtrl GetAnnotationsOnPage:pageNumber];
    } error:&error];
    
    if (error) {
        NSLog(@"Error: There was an error while trying to find annotations in page number. %@", error.localizedDescription);
    }
    
    return annots;
}

+(NSArray<PTAnnot *> *)findAnnotsWithUniqueIDs:(NSArray <NSDictionary *>*)idPageNumberPairs documentController:(PTDocumentController *)documentController error:(NSError **)error
{
    NSMutableArray<PTAnnot *> *resultAnnots = [[NSMutableArray alloc] init];
    
    NSMutableDictionary <NSNumber *, NSMutableArray <NSString *> *> *pageNumberAnnotDict = [[NSMutableDictionary alloc] init];
    
    // put all annotations in a dict indexed by page number
    for (NSDictionary *idPageNumberPair in idPageNumberPairs) {
        NSNumber *pageNumber = [PdftronFlutterPlugin PT_idAsNSNumber:idPageNumberPair[PTAnnotPageNumberKey]];
        NSString *annotId = [PdftronFlutterPlugin PT_idAsNSString:idPageNumberPair[PTAnnotIdKey]];
        NSMutableArray <NSString *> *annotArray;
        if (!pageNumberAnnotDict[pageNumber]) {
            annotArray = [[NSMutableArray alloc] init];

        } else {
            annotArray = pageNumberAnnotDict[pageNumber];
        }
        
        [annotArray addObject:annotId];
        pageNumberAnnotDict[pageNumber] = annotArray;
    }
    
    // loop through page numbers
    for (NSNumber *pageNumber in [pageNumberAnnotDict allKeys]) {
        
        __block NSArray<PTAnnot *> * annotsOnCurrPage;
        
        [documentController.pdfViewCtrl DocLockReadWithBlock:^(PTPDFDoc * _Nullable doc) {
            annotsOnCurrPage = [PdftronFlutterPlugin getAnnotationsOnPage:[pageNumber intValue] documentController:documentController];
        } error:error];
        
        if (*error) {
            NSLog(@"Error: There was an error while trying to get annotations on page for doc. %@", (*error).localizedDescription);
            return nil;
        }
            
        for (PTAnnot *annotFromDoc in annotsOnCurrPage) {
            if (![annotFromDoc IsValid]) {
                continue;
            }
            
            NSString *annotUniqueId = nil;
            PTObj *annotUniqueIdObj = [annotFromDoc GetUniqueID];
            if ([annotUniqueIdObj IsValid]) {
                annotUniqueId = [annotUniqueIdObj GetAsPDFText];
            }
            if (annotUniqueId) {
                
                for (NSString *annotIdFromDict in pageNumberAnnotDict[pageNumber]) {
                    if ([annotIdFromDict isEqualToString:annotUniqueId]) {
                        [resultAnnots addObject:annotFromDoc];
                        break;
                    }
                }
            }
        }
    }
    
    return [resultAnnots copy];
}

- (void)handleOpenDocumentMethod:(NSDictionary<NSString *, id> *)arguments resultToken:(FlutterResult)flutterResult
{

    // Get document argument.
    NSString *document = nil;
    id documentValue = arguments[PTDocumentArgumentKey];
    if ([documentValue isKindOfClass:[NSString class]]) {
        document = (NSString *)documentValue;
    }
    
    if (document.length == 0) {
        // error handling
        return;
    }
    
    // Get (optional) password argument.
    NSString *password = nil;
    id passwordValue = arguments[PTPasswordArgumentKey];
    if ([passwordValue isKindOfClass:[NSString class]]) {
        password = (NSString *)passwordValue;
    }
    
    NSString* config = arguments[PTConfigArgumentKey];
    self.config = config;
    
    // get base
    
    if (!self.tabbedDocumentViewController) {
        [self initTabbedDocumentViewController];
    }
    
    [PdftronFlutterPlugin configureTabbedDocumentViewController:self.tabbedDocumentViewController withConfig:config];
    
    NSError* error;
    
    NSDictionary *configDict = [PdftronFlutterPlugin PT_idAsNSDict:[PdftronFlutterPlugin PT_JSONStringToId:config]];
    
    bool isBase64 = NO;
    if([[configDict allKeys] containsObject:PTIsBase64StringKey]) {
        NSNumber* isBase64Number= [PdftronFlutterPlugin getConfigValue:configDict configKey:PTIsBase64StringKey class:[NSNumber class] error:&error];
        if (error) {
            NSLog(@"An error occurs with config %@: %@", PTIsBase64StringKey, error.localizedDescription);
        }
        
        isBase64 = [isBase64Number boolValue];
    }
    
    if (!isBase64) {
        // Open a file URL.
        NSURL *fileURL = [[NSBundle mainBundle] URLForResource:document withExtension:@"pdf"];
        if ([document containsString:@"://"]) {
            fileURL = [NSURL URLWithString:document];
        } else if ([document hasPrefix:@"/"]) {
            fileURL = [NSURL fileURLWithPath:document];
        }
            
        [self.tabbedDocumentViewController openDocumentWithURL:fileURL
                                                      password:password];
    } else {
        NSString *base64FileExtension = @".pdf";
        if([[configDict allKeys] containsObject:PTBase64FileExtensionKey]) {
            NSString *extension = [PdftronFlutterPlugin getConfigValue:configDict configKey:PTBase64FileExtensionKey class:[NSString class] error:&error];
            if (error) {
                NSLog(@"An error occurs with config %@: %@", PTBase64FileExtensionKey, error.localizedDescription);
            } else {
                base64FileExtension = extension;
            }
            
            NSData *data = [[NSData alloc] initWithBase64EncodedString:document options:0];

            NSMutableString *path = [[NSMutableString alloc] init];
            [path appendFormat:@"%@tmp%@%@", NSTemporaryDirectory(), [[NSUUID UUID] UUIDString], base64FileExtension];

            NSURL *fileURL = [NSURL fileURLWithPath:path isDirectory:NO];
            NSError* error;

            [data writeToURL:fileURL options:NSDataWritingAtomic error:&error];
            
            if (error) {
                NSLog(@"Error: There was an error while trying to create a temporary file for base64 string. %@", error.localizedDescription);
                return;
            }
            
            [[(PTFlutterTabbedDocumentController *)(self.tabbedDocumentViewController) tempFiles] addObject:path];
            
            [self.tabbedDocumentViewController openDocumentWithURL:fileURL
                                                          password:password];
        }
    }
    
    if (!self.tabbedDocumentViewController.navigationController) {
        
        [self presentTabbedDocumentViewController];
    }
    
    ((PTFlutterDocumentController*)self.tabbedDocumentViewController.childViewControllers.lastObject).openResult = flutterResult;
    
    PTFlutterDocumentController *documentController = (PTFlutterDocumentController *) [self getDocumentController];
    if (!documentController.isDocCtrlrConfigured) {
        [[self class] configureDocumentController:documentController
                                           withConfig:self.config];
        documentController.docCtrlrConfigured = YES;
    }
}

- (void)importAnnotations:(NSString *)xfdf resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        
        flutterResult([FlutterError errorWithCode:@"import_annotations" message:@"Failed to import annotations" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    __block BOOL hasDownloader = NO;
    
    NSError* error;
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        hasDownloader = [doc HasDownloader];
    } error:&error];
    if (hasDownloader) {
        // too soon
        NSLog(@"Error: The document is still being downloaded.");
        flutterResult([FlutterError errorWithCode:@"import_annotation_command" message:@"Failed to import annotation command" details:@"Error: The document is still being downloaded."]);
        return;
    }
    
    PTAnnotationManager * const annotationManager = documentController.toolManager.annotationManager;
    
    NSError *updateError = nil;
    NSString *xfdfForImport = BauhubDenormalizeBauhubAreaMarkupXfdfForMobileImport(xfdf);
    const BOOL updateSuccess = [annotationManager updateAnnotationsWithXFDFString:xfdfForImport
                                                                            error:&updateError];
    if (!updateSuccess) {
        if (updateError) {
            NSLog(@"Error: There was an error while trying to import annotation command. %@", updateError.localizedDescription);
        }
        flutterResult([FlutterError errorWithCode:@"import_annotation_command" message:@"Failed to import annotation command" details:@"Error: There was an error while trying to import annotation command."]);
    } else {
        NSError *decorateError = nil;
        [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
            BauhubRestoreTranslucentAreaMarkupAppearancesInDoc(doc);
            BauhubDecorateAllImportedAreaPins(documentController.pdfViewCtrl, doc);
        } error:&decorateError];
        if (decorateError) {
            NSLog(@"BauhubDecorateAllImportedAreaPins: %@", decorateError.localizedDescription);
        }
        flutterResult(nil);
    }
}

/// Merges XFDF into the document (FDFMerge). Use for partial XFDF chunks; `importAnnotations` uses update/replace semantics.
- (void)mergeAnnotations:(NSString *)xfdf resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if (documentController.document == Nil) {
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"merge_annotations" message:@"Failed to merge annotations" details:@"Error: The document view controller has no document."]);
        return;
    }

    __block BOOL hasDownloader = NO;
    NSError *error = nil;
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        hasDownloader = [doc HasDownloader];
    } error:&error];
    if (hasDownloader) {
        NSLog(@"Error: The document is still being downloaded.");
        flutterResult([FlutterError errorWithCode:@"merge_annotations" message:@"Failed to merge annotations" details:@"Error: The document is still being downloaded."]);
        return;
    }

    NSString *xfdfForImport = BauhubDenormalizeBauhubAreaMarkupXfdfForMobileImport(xfdf);
    if (xfdfForImport.length == 0) {
        flutterResult(nil);
        return;
    }

    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    tmpPath = [tmpPath stringByAppendingPathExtension:@"xfdf"];
    NSError *writeErr = nil;
    if (![xfdfForImport writeToFile:tmpPath atomically:YES encoding:NSUTF8StringEncoding error:&writeErr]) {
        NSLog(@"mergeAnnotations: temp XFDF write failed: %@", writeErr);
        flutterResult([FlutterError errorWithCode:@"merge_annotations" message:@"Failed to write temp XFDF" details:writeErr.localizedDescription]);
        return;
    }

    __block NSError *opError = nil;
    NSError *lockError = nil;
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        @try {
            PTFDFDoc *fdfDoc = [PTFDFDoc CreateFromXFDF:tmpPath];
            [doc FDFMerge:fdfDoc];
            // No PTPDFDoc RefreshAnnotAppearances in this Tools SDK; Bauhub restore + Decorate + Update refresh the view.
            BauhubRestoreTranslucentAreaMarkupAppearancesInDoc(doc);
            BauhubDecorateAllImportedAreaPins(documentController.pdfViewCtrl, doc);
        } @catch (NSException *ex) {
            NSLog(@"mergeAnnotations: %@", ex);
            opError = [NSError errorWithDomain:@"PdftronFlutter" code:-1 userInfo:@{NSLocalizedDescriptionKey: ex.reason ?: ex.name}];
        }
    } error:&lockError];

    [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];

    if (lockError) {
        flutterResult([FlutterError errorWithCode:@"merge_annotations" message:@"Failed to merge annotations" details:lockError.localizedDescription]);
    } else if (opError) {
        flutterResult([FlutterError errorWithCode:@"merge_annotations" message:@"Failed to merge annotations" details:opError.localizedDescription]);
    } else {
        flutterResult(nil);
    }
}

- (void)exportAnnotations:(NSString *)annotationList resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        
        flutterResult([FlutterError errorWithCode:@"export_annotations" message:@"Failed to export annotations" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    NSError *error;
    
    if (!annotationList) {
        [documentController.pdfViewCtrl DocLockReadWithBlock:^(PTPDFDoc * _Nullable doc) {
            PTFDFDoc *fdfDoc = [doc FDFExtract:e_ptboth];
            NSString *raw = [fdfDoc SaveAsXFDFToString];
            flutterResult(BauhubNormalizeBauhubAreaMarkupXfdfForWebParity(raw));
        }error:&error];
        
        if (error) {
            NSLog(@"Error: Failed to extract fdf from doc. %@", error.localizedDescription);
            flutterResult([FlutterError errorWithCode:@"export_annotations" message:@"Failed to export annotations" details:@"Failed to extract fdf from doc."]);
        }
        return;
    }
    
    NSArray *annotArray = [PdftronFlutterPlugin PT_idAsArray:[PdftronFlutterPlugin PT_JSONStringToId:annotationList]];
    
    NSArray <PTAnnot *> *matchingAnnots = [PdftronFlutterPlugin findAnnotsWithUniqueIDs:annotArray documentController:documentController error:&error];
    
    if (error) {
        NSLog(@"Error: Failed to get annotations from doc. %@", error.localizedDescription);
        
        flutterResult([FlutterError errorWithCode:@"export_annotations" message:@"Failed to export annotations" details:@"Error: Failed to get annotations from doc."]);
        return;
    }
    
    if (matchingAnnots.count == 0) {
        flutterResult(@"");
        return;
    }
    
    PTVectorAnnot *resultAnnots = [[PTVectorAnnot alloc] init];
    for (PTAnnot *annot in matchingAnnots) {
        [resultAnnots add:annot];
    }
    
    __block NSString *resultString;
    [documentController.pdfViewCtrl DocLockReadWithBlock:^(PTPDFDoc * _Nullable doc) {
        
        PTFDFDoc *fdfDoc = [doc FDFExtractAnnots:resultAnnots];
        resultString = BauhubNormalizeBauhubAreaMarkupXfdfForWebParity([fdfDoc SaveAsXFDFToString]);
        
    } error:&error];
    
    if(error)
    {
        NSLog(@"Error: Failed to extract fdf from doc. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"export_annotations" message:@"Failed to export annotations" details:@"Error: Failed to extract fdf from doc."]);
    } else {
        flutterResult(resultString);
    }
}


- (void)flattenAnnotations:(bool)formsOnly resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    [documentController.toolManager changeTool:[PTPanTool class]];
    
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        
        flutterResult([FlutterError errorWithCode:@"flatten_annotations" message:@"Failed to flatten annotations" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    NSError *error;
    
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        [doc FlattenAnnotations:formsOnly];
    } error:&error];
    
    if(error)
    {
        NSLog(@"Error: Failed to flatten annotations from doc. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"flatten_annotations" message:@"Failed to flatten annotations" details:@"Error: Failed to flatten annotations from doc."]);
    } else {
        flutterResult(nil);
    }
}

- (void)deleteAnnotations:(NSString *)annotationList resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");

        flutterResult([FlutterError errorWithCode:@"delete_annotations" message:@"Failed to delete annotations" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    NSError* error;
    
    NSArray *annotArray = [PdftronFlutterPlugin PT_idAsArray:[PdftronFlutterPlugin PT_JSONStringToId:annotationList]];
    
    NSArray* matchingAnnots = [PdftronFlutterPlugin findAnnotsWithUniqueIDs:annotArray documentController:documentController error:&error];
    
    if (error) {
        NSLog(@"Error: Failed to get annotations from doc. %@", error.localizedDescription);
        
        flutterResult([FlutterError errorWithCode:@"delete_annotations" message:@"Failed to delete annotations" details:@"Error: Failed to get annotations from doc."]);
        return;
    }
    
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        for (PTAnnot *annot in matchingAnnots) {
            PTPage *page = [annot GetPage];
            if (page && [page IsValid]) {
                int pageNumber = [page GetIndex];
                // Bauhub area markups (square/polygon Comment/Attachment/Task)
                // own a separate decorative corner-pin stamp linked by custom
                // data — without this, deleting the parent leaves the pin
                // orphaned on the page (mirrors the Android `onAnnotationsPreRemove`
                // hook in `ViewerImpl`).
                PTBauhubRemoveDecorativePinsWhenParentShapeRemoved(
                    documentController.pdfViewCtrl, doc, annot, pageNumber);
                [documentController.toolManager willRemoveAnnotation:annot onPageNumber:pageNumber];

                [page AnnotRemoveWithAnnot:annot];
                [documentController.toolManager annotationRemoved:annot onPageNumber:pageNumber];
            }
        }
        [documentController.pdfViewCtrl Update:YES];
    } error:&error];
        
    if (error) {
        NSLog(@"Error: Failed to delete annotations from doc. %@", error.localizedDescription);
            
        flutterResult([FlutterError errorWithCode:@"delete_annotations" message:@"Failed to delete annotations" details:@"Error: Failed to delete annotations from doc."]);
        return;
    }
    
    [documentController.toolManager changeTool:[PTPanTool class]];
    
    flutterResult(nil);
}

- (void)deleteAllAnnotations:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");

        flutterResult([FlutterError errorWithCode:@"delete_all_annotations" message:@"Failed to delete all annotations" details:@"Error: The document view controller has no document."]);
        return;
    }

    NSError* error;

    if (error) {
        NSLog(@"Error: Failed to get annotations from doc. %@", error.localizedDescription);

        flutterResult([FlutterError errorWithCode:@"delete_all_annotations" message:@"Failed to delete all annotations" details:@"Error: Failed to delete all annotations from doc."]);
        return;
    }

    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        PTPageIterator *pageIterator = [doc GetPageIterator:1];
        int pageNumber = 1;
        while ([pageIterator HasNext]) {
            PTPage *page = [pageIterator Current];
            if ([page IsValid]) {
                int num_annots = [page GetNumAnnots];
                for (int i = num_annots - 1; i >= 0; i--)
                {
                    PTAnnot* annot = [page GetAnnot:i];
                    if (![annot IsValid] || annot == nil) {
                        continue;
                    }
                    if ([annot GetType] != e_ptLink && [annot GetType] != e_ptWidget) {
                        [documentController.toolManager willRemoveAnnotation:annot onPageNumber:pageNumber];
                        [page AnnotRemoveWithAnnot:annot];
                        [documentController.toolManager annotationRemoved:annot onPageNumber:pageNumber];
                    }
                }
            }
            [pageIterator Next];
            pageNumber++;
        }
    } error:&error];

    [documentController.pdfViewCtrl Update:YES];
    [documentController.toolManager changeTool:[PTPanTool class]];

    if (error) {
        NSLog(@"Error: Failed to delete all annotations from doc. %@", error.localizedDescription);

        flutterResult([FlutterError errorWithCode:@"delete_all_annotations" message:@"Failed to delete annotations" details:@"Error: Failed to delete annotations from doc."]);
        return;
    }

    flutterResult(nil);
}

- (void)selectAnnotation:(NSString *)annotation resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        
        flutterResult([FlutterError errorWithCode:@"select_annotations" message:@"Failed to select annotations" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    
    NSDictionary *annotationJson = [PdftronFlutterPlugin PT_idAsNSDict:[PdftronFlutterPlugin PT_JSONStringToId:annotation]];
    
    NSString *annotId = [PdftronFlutterPlugin PT_idAsNSString:annotationJson[PTAnnotIdKey]];
    int pageNumber = [[PdftronFlutterPlugin PT_idAsNSNumber:annotationJson[PTAnnotPageNumberKey]] intValue];
    
    NSError* error;
    
    PTAnnot *annot = [PdftronFlutterPlugin findAnnotWithUniqueID:annotId onPageNumber:pageNumber documentController:documentController error:&error];
    
    if (error) {
        NSLog(@"Error: Failed to find annotation with unique id. %@", error.localizedDescription);
        
        flutterResult([FlutterError errorWithCode:@"select_annotations" message:@"Failed to select annotations" details:@"Error: Failed to find annotation with unique id."]);
        return;
    }
    
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        [documentController.toolManager selectAnnotation:annot onPageNumber:pageNumber];
    } error:&error];
    
    if(error) {
        NSLog(@"Error: Failed to select annotation from doc. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"select_annotations" message:@"Failed to select annotations" details:@"Error: Failed to select annotation from doc."]);
    } else {
        flutterResult(nil);
    }
}

- (void)hideAnnotation:(NSString *)annotation resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        
        flutterResult([FlutterError errorWithCode:@"hide_annotation" message:@"Failed to hide annotation" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    
    NSDictionary *annotationJson = [PdftronFlutterPlugin PT_idAsNSDict:[PdftronFlutterPlugin PT_JSONStringToId:annotation]];
    
    NSString *annotId = [PdftronFlutterPlugin PT_idAsNSString:annotationJson[PTAnnotIdKey]];
    int pageNumber = [[PdftronFlutterPlugin PT_idAsNSNumber:annotationJson[PTAnnotPageNumberKey]] intValue];
    
    NSError* error;
    
    PTAnnot *annot = [PdftronFlutterPlugin findAnnotWithUniqueID:annotId onPageNumber:pageNumber documentController:documentController error:&error];
    
    if (error) {
        NSLog(@"Error: Failed to find annotation with unique id. %@", error.localizedDescription);
        
        flutterResult([FlutterError errorWithCode:@"hide_annotation" message:@"Failed to hide annotation" details:@"Error: Failed to find annotation"]);
        return;
    }
    
    if (annot == nil || ![annot IsValid]) {
        // Activity-feed filter calls hide preemptively — annotations that
        // weren't merged (e.g. resolved rows skipped at import) simply don't
        // exist in the doc yet. Mirrors Android: every channel result must
        // terminate or the awaiting Dart Future hangs forever.
        flutterResult(nil);
        return;
    }
    
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        [documentController.pdfViewCtrl HideAnnotation:annot];
        // Mirror onto any decorative corner pin attached to a Bauhub area markup so
        // the canvas never shows a floating pin without its area. Pure point-pin
        // annotations are no-ops in here (they don't have a parent shape), so the
        // [HideAnnotation:] above already handles them.
        PTBauhubSetDecorativePinsVisibilityForParentShape(
            documentController.pdfViewCtrl, doc, annot, pageNumber, NO);
        [documentController.pdfViewCtrl UpdateWithAnnot:annot page_num:pageNumber];
    } error:&error];
    
    if(error) {
        NSLog(@"Error: Failed to hide annotation from doc. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"hide_annotation" message:@"Failed to hide annotation" details:@"Error: Failed to hide annotation"]);
    } else {
        flutterResult(nil);
    }
}

- (void)hideAllAnnotations:(NSNumber *)pageNumber resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");

        flutterResult([FlutterError errorWithCode:@"hide_all_annotations" message:@"Failed to hide all annotations" details:@"Error: The document view controller has no document."]);
        return;
    }

    NSError* error;
    
    NSArray<PTAnnot *> *annotations = [documentController.pdfViewCtrl GetAnnotationsOnPage:[pageNumber intValue]];

    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        for (id annot in annotations) {
            [documentController.pdfViewCtrl HideAnnotation:annot];
        }
        [documentController.pdfViewCtrl Update];
    } error:&error];

    if(error) {
        NSLog(@"Error: Failed to hide annotation from doc. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"hide_all_annotations" message:@"Failed to hide all annotations" details:@"Error: Failed to hide all annotations"]);
    } else {
        flutterResult(nil);
    }
}

- (void)showAnnotation:(NSString *)annotation resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        
        flutterResult([FlutterError errorWithCode:@"show_annotation" message:@"Failed to show annotation" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    
    NSDictionary *annotationJson = [PdftronFlutterPlugin PT_idAsNSDict:[PdftronFlutterPlugin PT_JSONStringToId:annotation]];
    
    NSString *annotId = [PdftronFlutterPlugin PT_idAsNSString:annotationJson[PTAnnotIdKey]];
    int pageNumber = [[PdftronFlutterPlugin PT_idAsNSNumber:annotationJson[PTAnnotPageNumberKey]] intValue];
    
    NSError* error;
    
    PTAnnot *annot = [PdftronFlutterPlugin findAnnotWithUniqueID:annotId onPageNumber:pageNumber documentController:documentController error:&error];
    
    if (error) {
        NSLog(@"Error: Failed to find annotation with unique id. %@", error.localizedDescription);
        
        flutterResult([FlutterError errorWithCode:@"show_annotation" message:@"Failed to show annotation" details:@"Error: Failed to find annotation"]);
        return;
    }
    
    if (annot == nil || ![annot IsValid]) {
        // Same as hideAnnotation: activity-feed filter calls show preemptively
        // for annotations that the import-on-demand path hasn't merged yet.
        flutterResult(nil);
        return;
    }
    
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        [documentController.pdfViewCtrl ShowAnnotation:annot];
        // Re-show the matching decorative corner pin so a previously filtered-out
        // Bauhub area markup gets its full visual back (area + pin) in one call.
        PTBauhubSetDecorativePinsVisibilityForParentShape(
            documentController.pdfViewCtrl, doc, annot, pageNumber, YES);
        [documentController.pdfViewCtrl UpdateWithAnnot:annot page_num:pageNumber];
    } error:&error];
    
    if(error) {
        NSLog(@"Error: Failed to hide annotation from doc. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"show_annotation" message:@"Failed to show annotation" details:@"Error: Failed to hide annotation"]);
    } else {
        flutterResult(nil);
    }
}

- (void)setFlagsForAnnotations:(NSString *)annotationsWithFlags resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"set_flag_for_annotations" message:@"Failed to set flag for annotations" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    NSError* error;
    
    NSArray *annotationWithFlagsArray = [PdftronFlutterPlugin PT_idAsArray:[PdftronFlutterPlugin PT_JSONStringToId:annotationsWithFlags]];
        
    for (NSDictionary *currentAnnotationWithFlags in annotationWithFlagsArray)
    {
        NSDictionary *currentAnnotationDict = [PdftronFlutterPlugin PT_idAsNSDict:[PdftronFlutterPlugin PT_JSONStringToId:currentAnnotationWithFlags[PTAnnotationArgumentKey]]];
            
        NSString *currentAnnotationId = [PdftronFlutterPlugin PT_idAsNSString:currentAnnotationDict[PTAnnotIdKey]];
        int currentPageNumber = [[PdftronFlutterPlugin PT_idAsNSNumber:currentAnnotationDict[PTAnnotPageNumberKey]] intValue];
            
        PTAnnot *currentAnnot = [PdftronFlutterPlugin findAnnotWithUniqueID:currentAnnotationId onPageNumber:currentPageNumber documentController:documentController error:&error];
        
        if (error) {
            NSLog(@"Error: Failed to find annotation with unique id. %@", error.localizedDescription);
            continue;
        }
            
        NSArray *flagList = [PdftronFlutterPlugin PT_idAsArray:[PdftronFlutterPlugin PT_JSONStringToId:currentAnnotationWithFlags[PTFlagListKey]]];
            
        for (NSDictionary *currentFlagDict in flagList)
        {
            NSString *currentFlag = [PdftronFlutterPlugin PT_idAsNSString:currentFlagDict[PTFlagKey]];
            bool currentFlagValue = [PdftronFlutterPlugin PT_idAsBool:currentFlagDict[PTFlagValueKey]];
                
            int flagNumber = -1;
            if ([currentFlag isEqualToString:PTAnnotationFlagPrintKey]) {
                flagNumber = e_ptprint_annot;
            } else if ([currentFlag isEqualToString:PTAnnotationFlagHiddenKey]) {
                flagNumber = e_pthidden;
            } else if ([currentFlag isEqualToString:PTAnnotationFlagLockedKey]) {
                flagNumber = e_ptlocked;
            } else if ([currentFlag isEqualToString:PTAnnotationFlagLockedContentsKey]) {
                flagNumber = e_ptlocked_contents;
            } else if ([currentFlag isEqualToString:PTAnnotationFlagInvisibleKey]) {
                flagNumber = e_ptinvisible;
            } else if ([currentFlag isEqualToString:PTAnnotationFlagNoViewKey]) {
                flagNumber = e_ptno_view;
            } else if ([currentFlag isEqualToString:PTAnnotationFlagNoZoomKey]) {
                flagNumber = e_ptno_zoom;
            } else if ([currentFlag isEqualToString:PTAnnotationFlagNoRotateKey]) {
                flagNumber = e_ptno_rotate;
            } else if ([currentFlag isEqualToString:PTAnnotationFlagReadOnlyKey]) {
                flagNumber = e_ptread_only;
            } else if ([currentFlag isEqualToString:PTAnnotationFlagToggleNoViewKey]) {
                flagNumber = e_pttoggle_no_view;
            }
                
            if (flagNumber != -1) {
                    
                [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
                    [documentController.toolManager willModifyAnnotation:currentAnnot onPageNumber:currentPageNumber];
                    
                    [currentAnnot SetFlag:flagNumber value:currentFlagValue];
                    
                    [documentController.toolManager annotationModified:currentAnnot onPageNumber:currentPageNumber];
                    }error:&error];
                
                if (error) {
                    NSLog(@"Error: Failed to set flag for annotation. %@", error.localizedDescription);
                }
            }
        }
    }
    
    flutterResult(nil);
}

- (void)setPropertiesForAnnotation:(NSString *)annotation properties:(NSString *)properties resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"set_properties_for_annotation" message:@"Failed to set properties for annotation" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    NSDictionary *annotationMap = [PdftronFlutterPlugin PT_idAsNSDict:[PdftronFlutterPlugin PT_JSONStringToId:annotation]];
    
    NSString *annotId = [PdftronFlutterPlugin PT_idAsNSString:annotationMap[PTAnnotIdKey]];
    int pageNumber = [[PdftronFlutterPlugin PT_idAsNSNumber:annotationMap[PTAnnotPageNumberKey]] intValue];
    
    NSError* error;
    
    PTAnnot *annot = [PdftronFlutterPlugin findAnnotWithUniqueID:annotId onPageNumber:pageNumber documentController:documentController error:&error];
    
    if (error) {
        NSLog(@"Error: Failed to find annotation with unique id. %@", error.localizedDescription);
        
        flutterResult([FlutterError errorWithCode:@"set_properties_for_annotation" message:@"Failed to set properties for annotation" details:@"Error: Failed to find annotation with unique id."]);
        return;
    } else if (![annot IsValid]) {
        NSLog(@"Error: Failed to find annotation with unique id. The requested annotation does not exist");
        
        flutterResult([FlutterError errorWithCode:@"set_properties_for_annotation" message:@"Failed to set properties for annotation" details:@"Error: Failed to find annotation with unique id."]);
        return;
    }
    
    // Update the properties
    
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        
        NSDictionary *propertyMap = [PdftronFlutterPlugin PT_idAsNSDict:[PdftronFlutterPlugin PT_JSONStringToId:properties]];
        
        if (!propertyMap) {
            return;
        }
        
        [documentController.toolManager willModifyAnnotation:annot onPageNumber:pageNumber];
        
        // contents
        NSString* annotContents = [PdftronFlutterPlugin PT_idAsNSString:propertyMap[PTContentsAnnotationPropertyKey]];
        if (annotContents) {
            [annot SetContents:annotContents];
        }
        
        // rect
        NSDictionary *annotRect = [PdftronFlutterPlugin PT_idAsNSDict:[PdftronFlutterPlugin PT_JSONStringToId:propertyMap[PTRectAnnotationPropertyKey]]];
        if (annotRect) {
            NSNumber *rectX1 = [PdftronFlutterPlugin PT_idAsNSNumber:annotRect[PTX1Key]];
            NSNumber *rectY1 = [PdftronFlutterPlugin PT_idAsNSNumber:annotRect[PTY1Key]];
            NSNumber *rectX2 = [PdftronFlutterPlugin PT_idAsNSNumber:annotRect[PTX2Key]];
            NSNumber *rectY2 = [PdftronFlutterPlugin PT_idAsNSNumber:annotRect[PTY2Key]];
            if (rectX1 && rectY1 && rectX2 && rectY2) {
                PTPDFRect *rect = [[PTPDFRect alloc] initWithX1:[rectX1 doubleValue] y1:[rectY1 doubleValue] x2:[rectX2 doubleValue] y2:[rectY2 doubleValue]];
                [annot SetRect:rect];
            }
        }
        
        // rotation
        NSNumber *annotRotation = [PdftronFlutterPlugin PT_idAsNSNumber:propertyMap[PTRotationAnnotationPropertyKey]];
        if (annotRotation) {
            [annot SetRotation:annotRotation.intValue];
            [annot RefreshAppearance];
        }
        
        if ([annot IsMarkup]) {
            PTMarkup *markupAnnot = [[PTMarkup alloc] initWithAnn:annot];
            
            // subject
            NSString *annotSubject = [PdftronFlutterPlugin PT_idAsNSString:propertyMap[PTSubjectAnnotationPropertyKey]];
            if (annotSubject) {
                [markupAnnot SetSubject:annotSubject];
            }
            
            // title
            NSString *annotTitle = [PdftronFlutterPlugin PT_idAsNSString:propertyMap[PTTitleAnnotationPropertyKey]];
            if (annotTitle) {
                [markupAnnot SetTitle:annotTitle];
            }
            
            // contentRect
            NSDictionary *annotContentRect = [PdftronFlutterPlugin PT_idAsNSDict:[PdftronFlutterPlugin PT_JSONStringToId:propertyMap[PTContentRectAnnotationPropertyKey]]];
            if (annotRect) {
                NSNumber *rectX1 = [PdftronFlutterPlugin PT_idAsNSNumber:annotContentRect[PTX1Key]];
                NSNumber *rectY1 = [PdftronFlutterPlugin PT_idAsNSNumber:annotContentRect[PTY1Key]];
                NSNumber *rectX2 = [PdftronFlutterPlugin PT_idAsNSNumber:annotContentRect[PTX2Key]];
                NSNumber *rectY2 = [PdftronFlutterPlugin PT_idAsNSNumber:annotContentRect[PTY2Key]];
                if (rectX1 && rectY1 && rectX2 && rectY2) {
                    PTPDFRect *contentRect = [[PTPDFRect alloc] initWithX1:[rectX1 doubleValue] y1:[rectY1 doubleValue] x2:[rectX2 doubleValue] y2:[rectY2 doubleValue]];
                    [markupAnnot SetContentRect:contentRect];
                }
            }
        }
        
        [documentController.pdfViewCtrl UpdateWithAnnot:annot page_num:(int)pageNumber];
        
        [documentController.toolManager annotationModified:annot onPageNumber:(int)pageNumber];
    } error:&error];
    
    if (error) {
        NSLog(@"Error: Failed to set properties for annotation from doc. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"set_properties_for_annotation" message:@"Failed to set properties for annotation" details:@"Error: Failed to set properties for annotation from doc."]);
    } else {
        flutterResult(nil);
    }
}

- (void)groupAnnotations:(NSString *)primaryAnnotation subAnnotations:(NSString *)subAnnotations resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"group_annotations" message:@"Failed to group annotations" details:@"Error: The document view controller has no document."]);
        return;
    }

    NSDictionary *annotationMap = [PdftronFlutterPlugin PT_idAsNSDict:[PdftronFlutterPlugin PT_JSONStringToId:primaryAnnotation]];

    NSString *annotId = [PdftronFlutterPlugin PT_idAsNSString:annotationMap[PTAnnotIdKey]];
    int pageNumber = [[PdftronFlutterPlugin PT_idAsNSNumber:annotationMap[PTAnnotPageNumberKey]] intValue];

    NSError* error;

    // parent annotation
    PTAnnot *mainAnnot = [PdftronFlutterPlugin findAnnotWithUniqueID:annotId onPageNumber:pageNumber documentController:documentController error:&error];

    if (error) {
        NSLog(@"Error: Failed to find annotation with unique id. %@", error.localizedDescription);

        flutterResult([FlutterError errorWithCode:@"group_annotations" message:@"Failed to group annotations" details:@"Error: Failed to find main annotation with unique id."]);
        return;
    } else if (![mainAnnot IsValid]) {
        NSLog(@"Error: Failed to find main annotation with unique id. The requested annotation does not exist");

        flutterResult([FlutterError errorWithCode:@"group_annotations" message:@"Failed to set properties for annotation" details:@"Error: Failed to find main annotation with unique id."]);
        return;
    }

    // child annotations
    NSArray *annotArray = [PdftronFlutterPlugin PT_idAsArray:[PdftronFlutterPlugin PT_JSONStringToId:subAnnotations]];

    NSArray <PTAnnot *> *matchingAnnots = [PdftronFlutterPlugin findAnnotsWithUniqueIDs:annotArray documentController:documentController error:&error];

    if (error) {
        NSLog(@"Error: Failed to get annotations from doc. %@", error.localizedDescription);

        flutterResult([FlutterError errorWithCode:@"group_annotations" message:@"Failed to group annotations" details:@"Error: Failed to get child annotations from doc."]);
        return;
    }

    if (matchingAnnots.count == 0) {
        flutterResult(@"");
        return;
    }

    // group the annotations

    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        NSString *mainAnnotID = [mainAnnot GetUniqueIDAsString];
        if (mainAnnotID == nil) {
            mainAnnotID = [NSUUID UUID].UUIDString;
            int bytes = (int)[mainAnnotID lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            [mainAnnot SetUniqueID:mainAnnotID id_buf_sz:bytes];
        }
        for (PTAnnot *annot in matchingAnnots) {
            [documentController.toolManager willModifyAnnotation:annot onPageNumber:pageNumber];

            PTObj *annotSDFObj = [annot GetSDFObj];
            [annotSDFObj EraseDictElementWithKey:@"RT"];
            [annotSDFObj EraseDictElementWithKey:@"IRT"];
            if (![annot isEqualTo:mainAnnot]) {
                [annotSDFObj PutName:@"RT" name:@"Group"];
                [annotSDFObj Put:@"IRT" obj:[mainAnnot GetSDFObj]];
            }
            [documentController.toolManager annotationModified:annot onPageNumber:(int)pageNumber];
        }
    } error:&error];

    if (error) {
        NSLog(@"Error: Failed to group annotations from doc. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"group_annotations" message:@"Failed to group annotations" details:@"Error: Failed to group annotations from doc."]);
    } else {
        flutterResult(nil);
    }
}

- (void)ungroupAnnotations:(NSString *)annotations resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"ungroup_annotations" message:@"Failed to ungroup annotations" details:@"Error: The document view controller has no document."]);
        return;
    }

    // annotations
    NSArray *annotArray = [PdftronFlutterPlugin PT_idAsArray:[PdftronFlutterPlugin PT_JSONStringToId:annotations]];

    NSError* error;
    NSArray <PTAnnot *> *matchingAnnots = [PdftronFlutterPlugin findAnnotsWithUniqueIDs:annotArray documentController:documentController error:&error];

    if (error) {
        NSLog(@"Error: Failed to get annotations from doc. %@", error.localizedDescription);

        flutterResult([FlutterError errorWithCode:@"ungroup_annotations" message:@"Failed to ungroup annotations" details:@"Error: Failed to get annotations from doc."]);
        return;
    }

    if (matchingAnnots.count == 0) {
        flutterResult(@"");
        return;
    }

    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        for (NSDictionary *currentAnnotation in annotArray)
        {
            NSString *currentAnnotationId = [PdftronFlutterPlugin PT_idAsNSString:currentAnnotation[PTAnnotIdKey]];
            int pageNumber = [[PdftronFlutterPlugin PT_idAsNSNumber:currentAnnotation[PTAnnotPageNumberKey]] intValue];

            NSError* findAnnotError;
            PTAnnot *annot = [PdftronFlutterPlugin findAnnotWithUniqueID:currentAnnotationId onPageNumber:pageNumber documentController:documentController error:&findAnnotError];
            if (findAnnotError) {
                NSLog(@"Error: Failed to find annotation with unique id. %@", findAnnotError.localizedDescription);
                continue;
            }

            PTObj *annotSDFObj = [annot GetSDFObj];
            [documentController.toolManager willModifyAnnotation:annot onPageNumber:(int)pageNumber];
            [annotSDFObj EraseDictElementWithKey:@"RT"];
            [annotSDFObj EraseDictElementWithKey:@"IRT"];
            [documentController.toolManager annotationModified:annot onPageNumber:(int)pageNumber];
        }
    } error:&error];

    if (error) {
        NSLog(@"Error: Failed to ungroup annotations from doc. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"ungroup_annotations" message:@"Failed to ungroup annotations" details:@"Error: Failed to ungroup annotations from doc."]);
    } else {
        flutterResult(nil);
    }
}

- (void)importAnnotationCommand:(NSString *)xfdfCommand resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"import_annotation_command" message:@"Failed to import annotation command" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    __block BOOL hasDownloader = NO;
    
    NSError* error;
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        hasDownloader = [doc HasDownloader];
    } error:&error];
    if (hasDownloader) {
        // too soon
        NSLog(@"Error: The document is still being downloaded.");
        flutterResult([FlutterError errorWithCode:@"import_annotation_command" message:@"Failed to import annotation command" details:@"Error: The document is still being downloaded."]);
        return;
    }

    PTAnnotationManager * const annotationManager = documentController.toolManager.annotationManager;
    
    NSError *updateError = nil;
    NSString *commandForImport = BauhubDenormalizeBauhubAreaMarkupXfdfForMobileImport(xfdfCommand);
    const BOOL updateSuccess = [annotationManager updateAnnotationsWithXFDFCommand:commandForImport
                                                                             error:&updateError];
    if (!updateSuccess) {
        if (updateError) {
            NSLog(@"Error: There was an error while trying to import annotation command. %@", updateError.localizedDescription);
        }
        flutterResult([FlutterError errorWithCode:@"import_annotation_command" message:@"Failed to import annotation command" details:@"Error: There was an error while trying to import annotation command."]);
    } else {
        NSError *decorateError = nil;
        [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
            BauhubRestoreTranslucentAreaMarkupAppearancesInDoc(doc);
            BauhubDecorateAllImportedAreaPins(documentController.pdfViewCtrl, doc);
        } error:&decorateError];
        if (decorateError) {
            NSLog(@"Bauhub importAnnotationCommand decorate: %@", decorateError.localizedDescription);
        }
        flutterResult(nil);
    }
}

- (void)importBookmarks:(NSString *)bookmarkJson resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"import_bookmark_json" message:@"Failed to import bookmark json" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    NSError* error;
    
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        if([doc HasDownloader])
        {
            // too soon
            NSLog(@"Error: The document is still being downloaded.");
            flutterResult([FlutterError errorWithCode:@"import_bookmark_json" message:@"Failed to import bookmark json" details:@"Error: The document is still being downloaded."]);
            return;
        }

        [PTBookmarkManager.defaultManager importBookmarksForDoc:doc fromJSONString:bookmarkJson];

    } error:&error];
    
    if(error)
    {
        NSLog(@"Error: There was an error while trying to import annotation command. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"import_bookmark_json" message:@"Failed to import bookmark json" details:@"Error: There was an error while trying to import annotation command."]);
    } else {
        flutterResult(nil);
    }
}

- (void)addBookmark:(NSString *)title pageNumber:(NSNumber *)pageNumber resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"add_bookmark" message:@"Failed to add bookmark" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    NSError* error;
    __block PTUserBookmark * bookmark;
    
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        if([doc HasDownloader])
        {
            // too soon
            NSLog(@"Error: The document is still being downloaded.");
            flutterResult([FlutterError errorWithCode:@"add_bookmark" message:@"Failed to add bookmark" details:@"Error: The document is still being downloaded."]);
            return;
        }
        
        // Export bookmarks to JSON, then to array.
        NSString* json = [PTBookmarkManager.defaultManager exportBookmarksFromDoc:doc];
        NSMutableArray<PTUserBookmark *> * bookmarks = [NSMutableArray arrayWithArray:[PTBookmarkManager.defaultManager bookmarksFromJSONString:json]];
        bookmark = [[PTUserBookmark alloc] initWithTitle:title pageNumber:[pageNumber intValue]];
        [bookmarks addObject:bookmark];
        
        // Convert array back to JSON and import.
        NSString* newJson = [PTBookmarkManager.defaultManager JSONStringFromBookmarks:bookmarks];
        [PTBookmarkManager.defaultManager importBookmarksForDoc:doc fromJSONString:newJson];

    } error:&error];
    
    if(error)
    {
        NSLog(@"Error: There was an error while trying to add bookmark. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"add_bookmark" message:@"Failed to add bookmark" details:@"Error: There was an error while trying to add bookmark."]);
    } else {
        flutterResult(nil);
    }
    
    // Raise event.
    PTBookmarkViewController *bookmarkViewController = documentController.navigationListsViewController.bookmarkViewController;
    PTFlutterDocumentController *flutterDocumentController = (PTFlutterDocumentController *) documentController;
    [flutterDocumentController bookmarkViewController:bookmarkViewController didAddBookmark:bookmark];
}

- (void)saveDocument:(FlutterResult)flutterResult
{
    PTFlutterDocumentController *documentController = (PTFlutterDocumentController *)[self getDocumentController];
    
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"save_document" message:@"Failed to save document" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    NSString *filePath = documentController.coordinatedDocument.fileURL.path;
    
    [documentController saveDocument:e_ptincremental completionHandler:^(BOOL success) {
        if (![documentController isBase64]) {
            flutterResult(success ? filePath : nil);
        } else if (!success) {
            flutterResult(nil);
        } else {
            __block NSString *base64String = nil;
            NSError *error = nil;
            [documentController.pdfViewCtrl DocLockReadWithBlock:^(PTPDFDoc * _Nullable doc) {
                NSData *data = [doc SaveToBuf:0];

                base64String = [data base64EncodedStringWithOptions:0];
            } error:&error];
            flutterResult((error == nil) ? base64String : nil);
        }
    }];
}

- (void)commitTool:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    PTToolManager *toolManager = documentController.toolManager;
    if ([toolManager.tool respondsToSelector:@selector(commitAnnotation)]) {
        [toolManager.tool performSelector:@selector(commitAnnotation)];

        [toolManager changeTool:[PTPanTool class]];

        flutterResult([NSNumber numberWithBool:YES]);
    } else {
        flutterResult([NSNumber numberWithBool:NO]);
    }
}

- (void)getPageCount:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"get_page_count" message:@"Failed to get page count" details:@"Error: The document view controller has no document."]);
        return;
    }

    flutterResult([NSNumber numberWithInt:documentController.pdfViewCtrl.pageCount]);
}

- (void)undo:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if (documentController.undoManager == Nil) {
        NSLog(@"Error: The document view controller has no undo manager.");
        flutterResult([FlutterError errorWithCode:@"undo" message:@"Failed to undo" details:@"Error: The document view controller has no undo manager."]);
        return;
    }
    
    [documentController.undoManager undo];
    flutterResult(nil);
}

- (void)redo:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if (documentController.undoManager == Nil) {
        NSLog(@"Error: The document view controller has no undo manager.");
        flutterResult([FlutterError errorWithCode:@"redo" message:@"Failed to redo" details:@"Error: The document view controller has no undo manager."]);
        return;
    }
    
    [documentController.undoManager redo];
    flutterResult(nil);
}

- (void)canUndo:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if (documentController.undoManager == Nil) {
        NSLog(@"Error: The document view controller has no undo manager.");
        flutterResult([FlutterError errorWithCode:@"undo" message:@"Failed to get canUndo" details:@"Error: The document view controller has no undo manager."]);
        return;
    }
    bool canUndo = [documentController.undoManager canUndo];
    flutterResult([NSNumber numberWithBool:canUndo]);
}

- (void)canRedo:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if (documentController.undoManager == Nil) {
        NSLog(@"Error: The document view controller has no undo manager.");
        flutterResult([FlutterError errorWithCode:@"redo" message:@"Failed to get canRedo" details:@"Error: The document view controller has no undo manager."]);
        return;
    }
    
    bool canRedo = [documentController.undoManager canRedo];
    flutterResult([NSNumber numberWithBool:canRedo]);
}

- (void)getPageCropBox:(NSNumber *)pageNumber resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"get_page_crop_box" message:@"Failed to get page crop box" details:@"Error: The document view controller has no document."]);
        return;
    }
    
    NSError *error;
    [documentController.pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        
        PTPage *page = [doc GetPage:[pageNumber intValue]];
        if (page) {
            PTPDFRect *rect = [page GetCropBox];
            NSDictionary<NSString *, NSNumber *> *map = @{
                PTX1Key: @([rect GetX1]),
                PTY1Key: @([rect GetY1]),
                PTX2Key: @([rect GetX2]),
                PTY2Key: @([rect GetY2]),
                PTWidthKey: @([rect Width]),
                PTHeightKey: @([rect Height]),
            };
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:map options:0 error:nil];
            NSString *res = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            flutterResult(res);
        } else {
            flutterResult(nil);
        }

    } error:&error];
    
    if(error)
    {
        NSLog(@"Error: There was an error while trying to get page crop box. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"save_document" message:@"Failed to get page crop box" details:@"Error: There was an error while trying to get page crop box"]);
    }
}

- (void)getPageRotation:(NSNumber *)pageNumber resultToken:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"get_page_rotation" message:@"Failed to get page rotation" details:@"Error: The document view controller has no document."]);
        return;
    }

    __block NSNumber *pageRotation;
    NSError* error;
    [documentController.pdfViewCtrl DocLockReadWithBlock:^(PTPDFDoc * _Nullable doc) {
        PTRotate rotation = [[doc GetPage:pageNumber.unsignedIntValue] GetRotation];
        pageRotation = [NSNumber numberWithInt:(rotation * 90)];
    } error:&error];

    if (error) {
        NSLog(@"Error: There was an error while trying to get the page rotation for page number. %@", error.localizedDescription);
    }
    flutterResult(pageRotation);
}

- (void)rotateClockwise:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    [documentController.pdfViewCtrl RotateClockwise];
    flutterResult(nil);
}

- (void)rotateCounterClockwise:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    [documentController.pdfViewCtrl RotateCounterClockwise];
    flutterResult(nil);
}

- (void)setCurrentPage:(NSNumber *)pageNumber resultToken:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    flutterResult([NSNumber numberWithBool:[documentController.pdfViewCtrl SetCurrentPage:[pageNumber intValue]]]);
}

- (void)gotoPreviousPage:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    flutterResult([NSNumber numberWithBool:[documentController.pdfViewCtrl GotoPreviousPage]]);
}

- (void)gotoNextPage:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    flutterResult([NSNumber numberWithBool:[documentController.pdfViewCtrl GotoNextPage]]);
}

- (void)gotoFirstPage:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    flutterResult([NSNumber numberWithBool:[documentController.pdfViewCtrl GotoFirstPage]]);
}

- (void)gotoLastPage:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    flutterResult([NSNumber numberWithBool:[documentController.pdfViewCtrl GotoLastPage]]);
}

- (void)getCurrentPage:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    flutterResult([NSNumber numberWithInt:documentController.pdfViewCtrl.currentPage]);
}

- (void)getZoom:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    double zoom = documentController.pdfViewCtrl.zoom * documentController.pdfViewCtrl.zoomScale;
    flutterResult([NSNumber numberWithDouble:zoom]);
}

- (void)setZoomLimits:(FlutterResult)flutterResult call:(FlutterMethodCall*)call {
    PTDocumentController *documentController = [self getDocumentController];
    NSString * zoomLimitMode = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTZoomLimitModeKey]];
    double maximum = [call.arguments[PTMaximumKey] doubleValue];
    double minimum = [call.arguments[PTMinimumKey] doubleValue];
    if ([zoomLimitMode isEqualToString:PTZoomLimitAbsoluteKey]) {
        [documentController.pdfViewCtrl SetZoomLimits:e_trn_zoom_limit_absolute Minimum:minimum Maxiumum:maximum];
    } else if ([zoomLimitMode isEqualToString:PTZoomLimitRelativeKey]) {
        [documentController.pdfViewCtrl SetZoomLimits:e_trn_zoom_limit_relative Minimum:minimum Maxiumum:maximum];
    } else if ([zoomLimitMode isEqualToString:PTZoomLimitNoneKey]) {
        [documentController.pdfViewCtrl SetZoomLimits:e_trn_zoom_limit_none Minimum:minimum Maxiumum:maximum];
    }
    flutterResult(nil);
}

-(void)smartZoom:(FlutterResult)flutterResult call:(FlutterMethodCall*)call {
    PTDocumentController *documentController = [self getDocumentController];
    int x = [call.arguments[PTXKey] intValue];
    int y = [call.arguments[PTYKey] intValue];
    bool animated = [PdftronFlutterPlugin PT_idAsBool:call.arguments[PTAnimatedArgumentKey]];
    [documentController.pdfViewCtrl SmartZoomX:(double)x y:(double)y animated:animated];
    flutterResult(nil);
}

- (void)getSavedSignatures:(FlutterResult)flutterResult {
    PTSignaturesManager *signaturesManager = [[PTSignaturesManager alloc] init];
    NSUInteger numOfSignatures = [signaturesManager numberOfSavedSignatures];
    NSMutableArray<NSString*> *signatures = [[NSMutableArray alloc] initWithCapacity:numOfSignatures];
    
    for (NSInteger i = 0; i < numOfSignatures; i++) {
        signatures[i] = [[signaturesManager savedSignatureAtIndex:i] GetFileName];
    }

    flutterResult(signatures);
}

- (void)getSavedSignatureFolder:(FlutterResult)flutterResult {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = paths[0];

    NSString* fullPath = [libraryDirectory stringByAppendingPathComponent:@"PTSignaturesManager_signatureDirectory"];
    flutterResult(fullPath);
}

- (void)getDocumentPath:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    flutterResult(documentController.coordinatedDocument.fileURL.path);
}

- (void)setToolMode:(NSString *)toolMode resultToken:(FlutterResult)flutterResult;
{
    PTDocumentController *documentController = [self getDocumentController];
    Class toolClass = Nil;

    if ([toolMode isEqualToString:PTAnnotationEditToolKey]) {
        // multi-select not implemented
    } else if ([toolMode isEqualToString:@"BauhubCommentAreaTool"] || [toolMode isEqualToString:@"BauhubAttachmentAreaTool"] || [toolMode isEqualToString:@"BauhubTaskAreaTool"]) {
        toolClass = [BauhubRectangleMarkupTool class];
    } else if ([toolMode isEqualToString:@"BauhubCommentPolygonTool"] || [toolMode isEqualToString:@"BauhubAttachmentPolygonTool"] || [toolMode isEqualToString:@"BauhubTaskPolygonTool"]) {
        toolClass = [BauhubPolygonMarkupTool class];
    } else if ([toolMode isEqualToString:@"BauhubCommentStampTool"] || [toolMode isEqualToString:@"BauhubAttachmentStampTool"]) {
        toolClass = [BauhubPinStampTool class];
    } else if ([toolMode containsString:@"BauhubTaskTool"]) {
        toolClass = [BauhubTaskTool class];
    } else if ([toolMode containsString:@"BauhubPlusIconTool"]) {
        toolClass = [BauhubPlusIconTool class];
    } else if([toolMode isEqualToString:PTAnnotationCreateStickyToolKey]) {
        toolClass = [PTStickyNoteCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateFreeHandToolKey]) {
        toolClass = [PTFreeHandCreate class];
    } else if ([toolMode isEqualToString:PTTextSelectToolKey]) {
        toolClass = [PTTextSelectTool class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateSoundToolKey]) {
        toolClass = [PTSound class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateTextHighlightToolKey]) {
        toolClass = [PTTextHighlightCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateTextUnderlineToolKey]) {
        toolClass = [PTTextUnderlineCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateTextSquigglyToolKey]) {
        toolClass = [PTTextSquigglyCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateTextStrikeoutToolKey]) {
        toolClass = [PTTextStrikeoutCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateFreeTextToolKey]) {
        toolClass = [PTFreeTextCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateCalloutToolKey]) {
        toolClass = [PTCalloutCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateSignatureToolKey]) {
        toolClass = [PTDigitalSignatureTool class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateLineToolKey]) {
        toolClass = [PTLineCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateArrowToolKey]) {
        toolClass = [PTArrowCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreatePolylineToolKey]) {
        toolClass = [PTPolylineCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateStampToolKey]) {
        toolClass = [PTImageStampCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateRectangleToolKey]) {
        toolClass = [PTRectangleCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateEllipseToolKey]) {
        toolClass = [PTEllipseCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreatePolygonToolKey]) {
        toolClass = [PTPolygonCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreatePolygonCloudToolKey]) {
        toolClass = [PTCloudCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateDistanceMeasurementToolKey]) {
        toolClass = [PTRulerCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreatePerimeterMeasurementToolKey]) {
        toolClass = [PTPerimeterCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateAreaMeasurementToolKey]) {
        toolClass = [PTAreaCreate class];
    } else if ([toolMode isEqualToString:PTEraserToolKey]) {
        toolClass = [PTEraser class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateFreeHighlighterToolKey]) {
        toolClass = [PTFreeHandHighlightCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateRubberStampToolKey]) {
        toolClass = [PTRubberStampCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateFileAttachmentToolKey]) {
        toolClass = [PTFileAttachmentCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateRedactionToolKey]) {
        toolClass = [PTRectangleRedactionCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateLinkToolKey]) {
        // TODO
    } else if ([toolMode isEqualToString:PTAnnotationCreateRedactionTextToolKey]) {
        toolClass = [PTTextRedactionCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationCreateLinkTextToolKey]) {
        // TODO
    } else if ([toolMode isEqualToString:PTFormCreateTextFieldToolKey]) {
        // TODO
    } else if ([toolMode isEqualToString:PTFormCreateCheckboxFieldToolKey]) {
        // TODO
    } else if ([toolMode isEqualToString:PTFormCreateSignatureFieldToolKey]) {
        // TODO
    } else if ([toolMode isEqualToString:PTFormCreateRadioFieldToolKey]) {
        // TODO
    } else if ([toolMode isEqualToString:PTFormCreateComboBoxFieldToolKey]) {
        // TODO
    } else if ([toolMode isEqualToString:PTFormCreateListBoxFieldToolKey]) {
        // TODO
    } else if ([toolMode isEqualToString:PTPencilKitDrawingToolKey]) {
        toolClass = [PTPencilDrawingCreate class];
    } else if ([toolMode isEqualToString:PTAnnotationSmartPenToolKey]) {
        toolClass = [PTSmartPen class];
    } else if ([toolMode isEqualToString:PTPanToolKey]) {
        toolClass = [PTPanTool class];
    }

    // Match Android's PluginUtils.setToolMode behaviour: an empty / unknown
    // mode key falls back to Pan instead of being a silent no-op. Without
    // this, Flutter's `_controller.setToolMode("")` (used as the universal
    // "disarm whatever Bauhub tool is active" call after a pin lands) left
    // BauhubTaskTool / BauhubPinStampTool armed on iOS — the next tap then
    // dropped a second pin even though the toolbar UI said no tool was
    // selected. The map above already lists every legitimate tool key, so a
    // null `toolClass` here always means "user wants to stop drawing".
    if (toolClass == Nil && [toolMode length] == 0) {
        toolClass = [PTPanTool class];
    }

    if (toolClass) {
        PTTool *tool = [documentController.toolManager changeTool:toolClass];

        tool.backToPanToolAfterUse = !((PTFlutterDocumentController *)documentController).isContinuousAnnotationEditingEnabled;

        if ([tool isKindOfClass:[PTFreeHandCreate class]]
            && ![tool isKindOfClass:[PTFreeHandHighlightCreate class]]) {
            ((PTFreeHandCreate *)tool).multistrokeMode = YES;
        }

        if ([tool isKindOfClass:[BauhubTaskTool class]]) {
            [((BauhubTaskTool *)tool) setTaskImageName:BauhubWebTaskPinImageName()];
        }

        if ([tool isKindOfClass:[BauhubPinStampTool class]]) {
            BauhubPinStampTool *pinTool = (BauhubPinStampTool *)tool;
            if ([toolMode isEqualToString:@"BauhubCommentStampTool"]) {
                pinTool.pinImageName = @"bauhubCommentPin";
                pinTool.pinSubject = @"Comment";
            } else if ([toolMode isEqualToString:@"BauhubAttachmentStampTool"]) {
                pinTool.pinImageName = @"bauhubAttachmentPin";
                pinTool.pinSubject = @"Attachment";
            }
        }

        if ([tool isKindOfClass:[BauhubRectangleMarkupTool class]]) {
            BauhubRectangleMarkupTool *rectTool = (BauhubRectangleMarkupTool *)tool;
            if ([toolMode isEqualToString:@"BauhubCommentAreaTool"]) {
                rectTool.bauhubSubject = @"Comment";
            } else if ([toolMode isEqualToString:@"BauhubAttachmentAreaTool"]) {
                rectTool.bauhubSubject = @"Attachment";
            } else if ([toolMode isEqualToString:@"BauhubTaskAreaTool"]) {
                rectTool.bauhubSubject = @"Task";
            }
        }

        if ([tool isKindOfClass:[BauhubPolygonMarkupTool class]]) {
            BauhubPolygonMarkupTool *polyTool = (BauhubPolygonMarkupTool *)tool;
            if ([toolMode isEqualToString:@"BauhubCommentPolygonTool"]) {
                polyTool.bauhubSubject = @"Comment";
            } else if ([toolMode isEqualToString:@"BauhubAttachmentPolygonTool"]) {
                polyTool.bauhubSubject = @"Attachment";
            } else if ([toolMode isEqualToString:@"BauhubTaskPolygonTool"]) {
                polyTool.bauhubSubject = @"Task";
            }
        }

        // Apryse applies PTColorDefaults when finishing a square/polygon — same mechanism as the built-in Draw tools.
        // Push Bauhub bar presets into PTColorDefaults so commit matches web (toolbar colours on mouse-up).
        if ([tool isKindOfClass:[BauhubRectangleMarkupTool class]] || [tool isKindOfClass:[BauhubPolygonMarkupTool class]]) {
            BauhubApplyAreaToolDrawPreviewDefaults(documentController.pdfViewCtrl);
        }
    }

    flutterResult(nil);
}

- (void)setFlagForFields:(NSArray <NSString *> *)fieldNames flag:(NSNumber *)flag flagValue:(bool)flagValue resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"set_flag_for_fields" message:@"Failed to set flag for fields" details:@"Error: The document view controller has no document."]);
        return;
    }

    PTPDFViewCtrl *pdfViewCtrl = documentController.pdfViewCtrl;
    PTFieldFlag fieldFlag = (PTFieldFlag)flag.intValue;
    NSError *error;

    [pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {
        for (NSString *fieldName in fieldNames) {
            PTField *field = [doc GetField:fieldName];
            if ([field IsValid]) {
                [field SetFlag:fieldFlag value:flagValue];
                [pdfViewCtrl UpdateWithField:field];
            }
        }
    } error:&error];

    if (error) {
        NSLog(@"Error: Failed to set flag for fields. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"set_flag_for_fields" message:@"Failed to set flag for fields" details:@"Error: Failed to set flag for fields."]);
    } else {
        flutterResult(nil);
    }
}

- (void)setValuesForFields:(NSString *)fieldWithValuesString resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    NSArray *fieldWithValues = [PdftronFlutterPlugin PT_idAsArray:[PdftronFlutterPlugin PT_JSONStringToId:fieldWithValuesString]];
    if(documentController.document == Nil)
    {
        // something is wrong, no document.
        NSLog(@"Error: The document view controller has no document.");
        flutterResult([FlutterError errorWithCode:@"set_values_for_fields" message:@"Failed to set values for fields" details:@"Error: The document view controller has no document."]);
        return;
    }

    PTPDFViewCtrl *pdfViewCtrl = documentController.pdfViewCtrl;
    NSError *error;

    [pdfViewCtrl DocLock:YES withBlock:^(PTPDFDoc * _Nullable doc) {

        for (NSDictionary *fieldWithValue in fieldWithValues) {
            NSString *fieldName = [PdftronFlutterPlugin PT_idAsNSString:fieldWithValue[PTFieldNameKey]];
            id fieldValue = fieldWithValue[PTFieldValueKey];
            PTField *field = [doc GetField:fieldName];

            if ([field IsValid]) {
                [self setFieldValue:field value:fieldValue pdfViewCtrl:pdfViewCtrl];
            }
        }

    } error:&error];

    if (error) {
        NSLog(@"Error: Failed to set values for fields. %@", error.localizedDescription);
        flutterResult([FlutterError errorWithCode:@"set_values_for_fields" message:@"Failed to set values for fields" details:@"Error: Failed to set values for fields."]);
    } else {
        flutterResult(nil);
    }
}

// write-lock required around this method
- (void)setFieldValue:(PTField *)field value:(id)value pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl
{
    const PTFieldType fieldType = [field GetType];

    // boolean or number
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *numberValue = (NSNumber *)value;

        if (fieldType == e_ptcheck) {
            const BOOL fieldValue = numberValue.boolValue;
            PTViewChangeCollection *changeCollection = [field SetValueWithBool:fieldValue];
            [pdfViewCtrl RefreshAndUpdate:changeCollection];
        }
        else if (fieldType == e_pttext) {
            NSString *fieldValue = numberValue.stringValue;

            PTViewChangeCollection *changeCollection = [field SetValueWithString:fieldValue];
            [pdfViewCtrl RefreshAndUpdate:changeCollection];
        }
    }
    // string
    else if ([value isKindOfClass:[NSString class]]) {
        NSString *fieldValue = (NSString *)value;

        if (fieldValue &&
            (fieldType == e_pttext || fieldType == e_ptradio || fieldType == e_ptchoice)) {
            PTViewChangeCollection *changeCollection = [field SetValueWithString:fieldValue];
            [pdfViewCtrl RefreshAndUpdate:changeCollection];
        }
    }
}

- (void)setLeadingNavButtonIcon:(NSString *)leadingNavButtonIcon resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"set_leading_nav_button_icon" message:@"Failed to set leading nav button icon" details:@"Error: The document view controller is not initialized."]);
        return;
    }

    [(PTFlutterDocumentController *)documentController setLeadingNavButtonIcon:leadingNavButtonIcon];
    
    flutterResult(nil);
}

-(void)closeAllTabs:(FlutterResult)flutterResult
{
    PTDocumentTabManager *tabManager = self.tabbedDocumentViewController.tabManager;
    NSArray<PTDocumentTabItem *> *items = [tabManager.items copy];
    
    // Close all tabs except the selected tab, which is displaying a view controller.
    for (PTDocumentTabItem *item in items) {
        if (item != tabManager.selectedItem) {
            [tabManager removeItem:item];
        }
    }
    // Close the selected tab last.
    if (tabManager.selectedItem) {
        [tabManager removeItem:tabManager.selectedItem];
    }
    
    flutterResult(nil);
}

-(void)exportAsImage:(NSNumber*)pageNumber dpi:(NSNumber*)dpi exportFormat:(NSString *)exportFormat filePath:(NSString*)filePath resultToken:(FlutterResult)flutterResult
{
    if (filePath == Nil) {
        PTDocumentController *documentController = [self getDocumentController];
        if(documentController == Nil)
        {
            // something is wrong, document view controller is not present
            NSLog(@"Error: The document view controller is not initialized.");
            flutterResult([FlutterError errorWithCode:@"export_as_image" message:@"Failed to export image from file" details:@"Error: The document view controller is not initialized."]);
            return;
        }
        
        PTPDFViewCtrl *pdfViewCtrl = documentController.pdfViewCtrl;
        
        [self exportAsImageHelper:[pdfViewCtrl GetDoc] pageNumber:pageNumber dpi:dpi exportFormat:exportFormat usesFilePath:NO resultToken:flutterResult];
    } else {
        [self exportAsImageHelper:[[PTPDFDoc alloc] initWithFilepath:filePath] pageNumber:pageNumber dpi:dpi exportFormat:exportFormat usesFilePath:YES resultToken:flutterResult];
    }
}

-(void)exportAsImageHelper:(PTPDFDoc*)doc pageNumber:(NSNumber*)pageNumber dpi:(NSNumber*)dpi exportFormat:(NSString *)exportFormat usesFilePath:(BOOL)usesFilePath resultToken:(FlutterResult)flutterResult
{
    __block NSString* imagePath;
    NSError *error;
    
    [doc LockReadWithBlock:^() {
        PTPDFDraw *draw = [[PTPDFDraw alloc] initWithDpi:[dpi doubleValue]];
        NSString* tempDir = NSTemporaryDirectory();
        NSString* fileName = [NSUUID UUID].UUIDString;
        imagePath = [tempDir stringByAppendingPathComponent:fileName];
        imagePath = [imagePath stringByAppendingPathExtension:exportFormat];
        [draw Export:[doc GetPage:[pageNumber doubleValue]] filename:imagePath format:exportFormat];
    }
    error:&error];
    
    if (error) {
        NSLog(@"Error: Failed to export image from file. %@", error.localizedDescription);
        NSString * errorCode = usesFilePath ? @"export_as_image_from_file_path" : @"export_as_image";
        flutterResult([FlutterError errorWithCode:errorCode message:@"Failed to export image from file" details:@"Error: Failed to export image from file"]);
    } else {
        flutterResult(imagePath);
    }
}
    
- (void)openAnnotationList:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if (!documentController.annotationListHidden) {
        PTNavigationListsViewController *navigationListsViewController = documentController.navigationListsViewController;
        if (navigationListsViewController) {
            navigationListsViewController.selectedViewController = navigationListsViewController.annotationViewController;
            [documentController showNavigationLists];
        }
    }
    
    flutterResult(nil);
}

- (void)openBookmarkList:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if (!documentController.bookmarkListHidden) {
        PTNavigationListsViewController *navigationListsViewController = documentController.navigationListsViewController;
        if (navigationListsViewController) {
            navigationListsViewController.selectedViewController = navigationListsViewController.bookmarkViewController;
            [documentController showNavigationLists];
        }
    }
    
    flutterResult(nil);
}

- (void)openOutlineList:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if (!documentController.outlineListHidden) {
        PTNavigationListsViewController *navigationListsViewController = documentController.navigationListsViewController;
        if (navigationListsViewController) {
            navigationListsViewController.selectedViewController = navigationListsViewController.outlineViewController;
            [documentController showNavigationLists];
        }
    }
    
    
    
    flutterResult(nil);
}

- (void)openLayersList:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if (!documentController.pdfLayerListHidden) {
        PTNavigationListsViewController *navigationListsViewController = documentController.navigationListsViewController;
        if (navigationListsViewController) {
            navigationListsViewController.selectedViewController = navigationListsViewController.pdfLayerViewController;
            [documentController showNavigationLists];
        }
    }
    
    flutterResult(nil);
}

-(void)openThumbnailsView:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"open_thumbnails_view" message:@"Failed to open thumbnails view" details:@"Error: The document view controller is not initialized."]);
        return;
    }
    
    [documentController showThumbnailsController];
    flutterResult(nil);
}

-(void)openAddPagesView:(FlutterResult)flutterResult rect:(NSDictionary *)rect
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"open_add_pages_view" message:@"Failed to open add pages view" details:@"Error: The document view controller is not initialized."]);
        return;
    }
    
    NSNumber *rectX1 = rect[PTRectX1Key];
    NSNumber *rectY1 = rect[PTRectY1Key];
    NSNumber *rectX2 = rect[PTRectX2Key];
    NSNumber *rectY2 = rect[PTRectY2Key];
    CGRect screenRect = CGRectMake([rectX1 doubleValue], [rectY1 doubleValue], [rectX2 doubleValue]-[rectX1 doubleValue], [rectY2 doubleValue]-[rectY1 doubleValue]);
    
    [documentController showAddPagesViewFromScreenRect:screenRect];
    flutterResult(nil);
}

-(void)openViewSettings:(FlutterResult)flutterResult rect:(NSDictionary *)rect
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"open_view_settings" message:@"Failed to open view settings" details:@"Error: The document view controller is not initialized."]);
        return;
    }
    
    NSNumber *rectX1 = rect[PTRectX1Key];
    NSNumber *rectY1 = rect[PTRectY1Key];
    NSNumber *rectX2 = rect[PTRectX2Key];
    NSNumber *rectY2 = rect[PTRectY2Key];
    CGRect screenRect = CGRectMake([rectX1 doubleValue], [rectY1 doubleValue], [rectX2 doubleValue]-[rectX1 doubleValue], [rectY2 doubleValue]-[rectY1 doubleValue]);
    [documentController showSettingsFromScreenRect:screenRect];
    flutterResult(nil);
}

-(void)openCrop:(FlutterResult)flutterResult
{
    // TODO: add a source rect option to the native API (similar to the openAddPagesView call)
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"open_crop" message:@"Failed to open crop" details:@"Error: The document view controller is not initialized."]);
        return;
    }
    PTFlutterDocumentController *flutterDocumentController = (PTFlutterDocumentController *) documentController;
    if (flutterDocumentController.isTopToolbarsHidden) {
        return;
    };
    if (documentController.navigationItem.rightBarButtonItem != nil) {
       [documentController showPageCropOptions:documentController.navigationItem.rightBarButtonItem];
    }
    flutterResult(nil);
}

-(void)openManualCrop:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"open_manual_crop" message:@"Failed to open manual crop" details:@"Error: The document view controller is not initialized."]);
        return;
    }
    [documentController showPageCropViewController];
    flutterResult(nil);
}

-(void)openSearch:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"open_search" message:@"Failed to open search" details:@"Error: The document view controller is not initialized."]);
        return;
    }
    
    [documentController showSearchViewController];
    flutterResult(nil);
}

-(void)startSearchMode:(NSString*)searchString matchCase:(bool)matchCase matchWholeWord:(bool)matchWholeWord resultToken:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"open_search" message:@"Failed to open search" details:@"Error: The document view controller is not initialized."]);
        return;
    }
    documentController.textSearchViewController.showsKeyboardOnViewDidAppear = NO;
    unsigned int mode = e_ptambient_string | e_ptpage_stop | e_pthighlight;
    if (matchCase) {
        mode |= e_ptcase_sensitive;
    }
    if (matchWholeWord) {
        mode |= e_ptwhole_word;
    }

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:documentController.textSearchViewController];
    nav.modalPresentationStyle = UIModalPresentationCustom;
    [documentController presentViewController:nav animated:NO completion:^{
        [documentController.textSearchViewController findText:searchString withSearchMode:mode];
    }];
    flutterResult(nil);
}

- (void)exitSearchMode:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"open_search" message:@"Failed to open search" details:@"Error: The document view controller is not initialized."]);
        return;
    }
    if (documentController.textSearchViewController.presentingViewController) {
        [documentController dismissViewControllerAnimated:YES completion:nil];
    }
    flutterResult(nil);
}

-(void)openTabSwitcher:(FlutterResult)flutterResult
{
    if (self.tabbedDocumentViewController) {
        [self.tabbedDocumentViewController showTabsList:self.tabbedDocumentViewController.tabBar];
        flutterResult(nil);
        return;
    } else {
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"open_tab_switcher" message:@"Failed to open tab switcher" details:@"Error: The document view controller is not initialized."]);
    }
}

-(void)openGoToPageView:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    if (documentController && documentController.pageIndicatorViewController) {
        PTPageIndicatorViewController * pageIndicator = documentController.pageIndicatorViewController;
        [pageIndicator presentGoToPageController];
        flutterResult(nil);
        return;
    } else {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"open_go_to_page_view" message:@"Failed to set open go to page view" details:@"Error: The document view controller is not initialized."]);
    }
}

-(void)openNavigationLists:(FlutterResult)flutterResult
{
    PTDocumentController *documentController = [self getDocumentController];
    PTNavigationListsViewController *navigationListsViewController = documentController.navigationListsViewController;
    if (navigationListsViewController) {
        [documentController showNavigationLists];
    }

    flutterResult(nil);
}

-(void)setBackgroundColor:(FlutterResult)flutterResult call:(FlutterMethodCall*)call {
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"set_background_color" message:@"Failed to set background color" details:@"Error: The document view controller is not initialized."]);
        return;
    }

    PTPDFViewCtrl *pdfViewCtrl = documentController.pdfViewCtrl;
        
    [pdfViewCtrl
     SetBackgroundColor:[call.arguments[PTRedKey] unsignedCharValue] g:[call.arguments[PTGreenKey] unsignedCharValue] b:[call.arguments[PTBlueKey] unsignedCharValue] a:255];
    flutterResult(nil);
}

-(void)setDefaultPageColor:(FlutterResult)flutterResult call:(FlutterMethodCall*)call {
    PTDocumentController *documentController = [self getDocumentController];
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"set_default_page_color" message:@"Failed to set default page color" details:@"Error: The document view controller is not initialized."]);
        return;
    }

    PTPDFViewCtrl *pdfViewCtrl = documentController.pdfViewCtrl;
        
    [pdfViewCtrl
        SetDefaultPageColor:[call.arguments[PTRedKey] unsignedCharValue] g:[call.arguments[PTGreenKey] unsignedCharValue] b:[call.arguments[PTBlueKey] unsignedCharValue]];
    [pdfViewCtrl Update:YES];

    flutterResult(nil);
}

-(void)getScrollPos:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];

    NSDictionary<NSString *, NSNumber *> * scrollPos = @{
        PTScrollHorizontalKey: [[NSNumber alloc] initWithDouble:[documentController.pdfViewCtrl GetHScrollPos]],
        PTScrollVerticalKey: [[NSNumber alloc] initWithDouble:[documentController.pdfViewCtrl GetVScrollPos]],
    };
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:scrollPos options:0 error:nil];
    NSString *res = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    flutterResult(res);
}

-(void)setHorizontalScrollPosition:(FlutterMethodCall*)call result:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    double horizontalScrollPos = [call.arguments[PTHorizontalScrollPositionArgumentKey] doubleValue];
    [documentController.pdfViewCtrl SetHScrollPos:horizontalScrollPos];
    flutterResult(nil);
}

-(void)setVerticalScrollPosition:(FlutterMethodCall*)call result:(FlutterResult)flutterResult {
    PTDocumentController *documentController = [self getDocumentController];
    double verticalScrollPos = [call.arguments[PTVerticalScrollPositionArgumentKey] doubleValue];
    [documentController.pdfViewCtrl SetVScrollPos:verticalScrollPos];
    flutterResult(nil);
}

-(void)zoomWithCenter:(FlutterResult)flutterResult call:(FlutterMethodCall*)call {
    PTDocumentController *documentController = [self getDocumentController];
    double zoom = [call.arguments[PTZoomRatioKey] doubleValue];
    int x = [call.arguments[PTXKey] intValue];
    int y = [call.arguments[PTYKey] intValue];
    [documentController.pdfViewCtrl SetZoomX:x Y:y Zoom:zoom];
    flutterResult(nil);
}

-(void)zoomToRect:(FlutterResult)flutterResult call:(FlutterMethodCall*)call {
    PTDocumentController *documentController = [self getDocumentController];
    
    int pageNumber = [call.arguments[PTPageNumberArgumentKey] intValue];
    double rectX1 = [call.arguments[PTX1Key] doubleValue];
    double rectY1 = [call.arguments[PTY1Key] doubleValue];
    double rectX2 = [call.arguments[PTX2Key] doubleValue];
    double rectY2 = [call.arguments[PTY2Key] doubleValue];
    
    if (rectX1 && rectY1 && rectX2 && rectY2) {
        PTPDFRect* rect = [[PTPDFRect alloc] initWithX1:rectX1 y1:rectY1 x2:rectX2 y2:rectY2];
        [documentController.pdfViewCtrl ShowRect:pageNumber rect:rect];
    }
}

// Hygen Generated Methods
- (void)setLayoutMode:(FlutterResult)flutterResult call:(FlutterMethodCall*)call
{
    PTDocumentController *documentController = [self getDocumentController];
    PTPDFViewCtrl *pdfViewCtrl = documentController.pdfViewCtrl;
    NSString* layoutMode = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTLayoutModeArgumentKey]];
    
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"set_layout_mode" message:@"Failed to set page presentation mode" details:@"Error: The document view controller is not initialized."]);
        return;
    }
    
    if ([layoutMode isEqualToString:PTSingleKey]) {
        [pdfViewCtrl SetPagePresentationMode:e_trn_single_page];
    }
    else if ([layoutMode isEqualToString:PTContinuousKey]) {
        [pdfViewCtrl SetPagePresentationMode:e_trn_single_continuous];
    }
    else if ([layoutMode isEqualToString:PTFacingKey]) {
        [pdfViewCtrl SetPagePresentationMode:e_trn_facing];
    }
    else if ([layoutMode isEqualToString:PTFacingContinuousKey]) {
        [pdfViewCtrl SetPagePresentationMode:e_trn_facing_continuous];
    }
    else if ([layoutMode isEqualToString:PTFacingCoverKey]) {
        [pdfViewCtrl SetPagePresentationMode:e_trn_facing_cover];
    }
    else if ([layoutMode isEqualToString:PTFacingCoverContinuousKey]) {
        [pdfViewCtrl SetPagePresentationMode:e_trn_facing_continuous_cover];
    }
    [pdfViewCtrl Update:YES];
    flutterResult(nil);
}

- (void)setFitMode:(FlutterResult)flutterResult call:(FlutterMethodCall*)call
{
    PTDocumentController *documentController = [self getDocumentController];
    PTPDFViewCtrl *pdfViewCtrl = documentController.pdfViewCtrl;
    NSString* fitMode = [PdftronFlutterPlugin PT_idAsNSString:call.arguments[PTFitModeArgumentKey]];
    
    if(documentController == Nil)
    {
        // something is wrong, document view controller is not present
        NSLog(@"Error: The document view controller is not initialized.");
        flutterResult([FlutterError errorWithCode:@"set_fit_mode" message:@"Failed to set page view mode" details:@"Error: The document view controller is not initialized."]);
        return;
    }
    
    if (!fitMode) {
        return;
    }
    
    if ([fitMode isEqualToString:PTFitPageKey]) {
        [pdfViewCtrl SetPageViewMode:e_trn_fit_page];
        [pdfViewCtrl SetPageRefViewMode:e_trn_fit_page];
    }
    else if ([fitMode isEqualToString:PTFitWidthKey]) {
        [pdfViewCtrl SetPageViewMode:e_trn_fit_width];
        [pdfViewCtrl SetPageRefViewMode:e_trn_fit_width];
    }
    else if ([fitMode isEqualToString:PTFitHeightKey]) {
        [pdfViewCtrl SetPageViewMode:e_trn_fit_height];
        [pdfViewCtrl SetPageRefViewMode:e_trn_fit_height];
    }
    else if ([fitMode isEqualToString:PTZoomKey]) {
        [pdfViewCtrl SetPageViewMode:e_trn_zoom];
        [pdfViewCtrl SetPageRefViewMode:e_trn_zoom];
    }
    
    [pdfViewCtrl Update:YES];
    flutterResult(nil);
}

- (void)getAnnotationsOnPage:(FlutterResult)result call:(FlutterMethodCall*)call
{
    PTDocumentController *documentController = [self getDocumentController];
    int pageNumber = [call.arguments[PTPageNumberArgumentKey] intValue];
    
    NSMutableArray *resultArray = [[NSMutableArray alloc] init];
    NSArray<PTAnnot *> *annots = [PdftronFlutterPlugin getAnnotationsOnPage:pageNumber documentController:documentController];
    
    for (PTAnnot *annot in annots) {
        NSString *uid = [annot GetUniqueIDAsString];
        if (uid) {
            NSDictionary *annotJson = @{
                PTAnnotationIdKey: uid,
                PTAnnotationPageNumberKey: [NSNumber numberWithInt:pageNumber],
            };
            [resultArray addObject:annotJson];
        }
    }

    result([PdftronFlutterPlugin PT_idToJSONString:resultArray]);
}


#pragma mark - Helper

- (PTDocumentController *)getDocumentController {
    return [PdftronFlutterPlugin PT_getSelectedDocumentController:self.tabbedDocumentViewController];
}

+ (PTDocumentController *)PT_getSelectedDocumentController:(PTTabbedDocumentViewController *)tabbedDocumentViewController {
    PTDocumentController* documentController = tabbedDocumentViewController.selectedViewController;
    
    if(documentController == Nil && tabbedDocumentViewController.childViewControllers.count == 1)
    {
        documentController = tabbedDocumentViewController.childViewControllers.lastObject;
    }
    return documentController;
}

+ (NSString *)PT_idAsNSString:(id)value
{
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    return nil;
}

+ (NSNumber *)PT_idAsNSNumber:(id)value
{
    if ([value isKindOfClass:[NSNumber class]]) {
        return (NSNumber *)value;
    }
    return nil;
}

+ (bool)PT_idAsBool:(id)value
{
    NSNumber* numericVal = [PdftronFlutterPlugin PT_idAsNSNumber:value];
    if (numericVal) {
        bool result = [numericVal boolValue];
        return result;
    }
    return false;
}

+ (NSDictionary *)PT_idAsNSDict:(id)value
{
    if ([value isKindOfClass:[NSDictionary class]]) {
        return (NSDictionary *)value;
    }
    return nil;
}

+ (NSArray *)PT_idAsArray:(id)value
{
    if ([value isKindOfClass:[NSArray class]]) {
        return (NSArray *)value;
    }
    return nil;
}

+ (NSString *)PT_idToJSONString:(id)infoId {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:infoId options:0 error:nil];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

+ (id)PT_JSONStringToId:(NSString *)jsonString {
    NSData *annotListData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    return [NSJSONSerialization JSONObjectWithData:annotListData options:kNilOptions error:nil];
}

+ (Class)toolClassForKey:(NSString *)key
{
    if ([key isEqualToString:PTAnnotationEditToolKey]) {
        return [PTAnnotSelectTool class];
    }
    else if ([key isEqualToString:PTAnnotationCreateStickyToolKey] ||
             [key isEqualToString:PTStickyToolButtonKey]) {
        return [PTStickyNoteCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateFreeHandToolKey] ||
             [key isEqualToString:PTFreeHandToolButtonKey]) {
        return [PTFreeHandCreate class];
    }
    else if ([key isEqualToString:PTTextSelectToolKey]) {
        return [PTTextSelectTool class];
    }
    else if ([key isEqualToString:PTAnnotationCreateTextHighlightToolKey] ||
             [key isEqualToString:PTHighlightToolButtonKey]) {
        return [PTTextHighlightCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateTextUnderlineToolKey] ||
             [key isEqualToString:PTUnderlineToolButtonKey]) {
        return [PTTextUnderlineCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateTextSquigglyToolKey] ||
             [key isEqualToString:PTSquigglyToolButtonKey]) {
        return [PTTextSquigglyCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateTextStrikeoutToolKey] ||
             [key isEqualToString:PTStrikeoutToolButtonKey]) {
        return [PTTextStrikeoutCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateFreeTextToolKey] ||
             [key isEqualToString:PTFreeTextToolButtonKey]) {
        return [PTFreeTextCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateCalloutToolKey] ||
             [key isEqualToString:PTCalloutToolButtonKey]) {
        return [PTCalloutCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateSignatureToolKey] ||
             [key isEqualToString:PTSignatureToolButtonKey]) {
        return [PTDigitalSignatureTool class];
    }
    else if ([key isEqualToString:PTAnnotationCreateLineToolKey] ||
             [key isEqualToString:PTLineToolButtonKey]) {
        return [PTLineCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateArrowToolKey] ||
             [key isEqualToString:PTArrowToolButtonKey]) {
        return [PTArrowCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreatePolylineToolKey] ||
             [key isEqualToString:PTPolylineToolButtonKey]) {
        return [PTPolylineCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateStampToolKey] ||
             [key isEqualToString:PTStampToolButtonKey]) {
        return [PTImageStampCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateRectangleToolKey] ||
             [key isEqualToString:PTRectangleToolButtonKey]) {
        return [PTRectangleCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateEllipseToolKey] ||
             [key isEqualToString:PTEllipseToolButtonKey]) {
        return [PTEllipseCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreatePolygonToolKey] ||
             [key isEqualToString:PTPolygonToolButtonKey]) {
        return [PTPolygonCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreatePolygonCloudToolKey] ||
             [key isEqualToString:PTCloudToolButtonKey]) {
        return [PTCloudCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateFileAttachmentToolKey]) {
        return [PTFileAttachmentCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateDistanceMeasurementToolKey]) {
        return [PTRulerCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreatePerimeterMeasurementToolKey]) {
        return [PTPerimeterCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateAreaMeasurementToolKey]) {
        return [PTAreaCreate class];
    }
    else if ([key isEqualToString:PTAnnotationCreateFreeHighlighterToolKey]) {
        return [PTFreeHandHighlightCreate class];
    }
    else if ([key isEqualToString:PTEraserToolKey]) {
        return [PTEraser class];
    }
    else if ([key isEqualToString:PTPanToolKey]) {
        return [PTPanTool class];
    }
    else if ([key isEqualToString:PTAnnotationSmartPenToolKey]) {
        return [PTSmartPen class];
    }
    else if ([key isEqualToString:PTPencilKitDrawingToolKey]) {
        return [PTPencilDrawingCreate class];
    }

    return Nil;
}

@end

#pragma mark - BauhubTaskTool
@interface BauhubTaskTool () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate>

@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, nullable) PTPDFPoint *touchPtPage;
@property (nonatomic, assign) BOOL isPencilTouch;

@end

@implementation BauhubTaskTool

@dynamic isPencilTouch;

- (Class)annotClass
{
    return [PTRubberStamp class];
}

+ (PTExtendedAnnotType)annotType
{
    return PTExtendedAnnotTypeImageStamp;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl handleTap:(UITapGestureRecognizer *)gestureRecognizer
{

    if( !(self.isPencilTouch == YES || self.toolManager.annotationsCreatedWithPencilOnly == NO) )
    {
        return YES;
    }

    CGPoint touchPoint = [gestureRecognizer locationInView:self.pdfViewCtrl];

    int pageNumber = [self.pdfViewCtrl GetPageNumberFromScreenPt:touchPoint.x y:touchPoint.y];
    if (pageNumber < 1) {
        return YES;
    }
    // Save page number for touch point.
    _pageNumber = pageNumber;
    self.endPoint = touchPoint;
    self.touchPtPage = [self.pdfViewCtrl ConvScreenPtToPagePt:[[PTPDFPoint alloc] initWithPx:self.endPoint.x py:self.endPoint.y] page_num:_pageNumber];

    UIImage *rawImage = [UIImage imageNamed:self.taskImageName];

    if (rawImage) {
        self.image = [self correctForRotation:rawImage];
        [self createImageStamp];
    } else {
        // Mirror Android: prefer the red web pin (task_dd1111) over the legacy
        // black task_111111 fallback so a stamp placed before
        // setTaskImageName: lands (or with an unknown / missing color asset)
        // still uses the brand pin instead of the old black artwork.
        UIImage *defaultImage = [UIImage imageNamed:@"task_dd1111"];
        if (!defaultImage) {
            defaultImage = [UIImage imageNamed:@"task_111111"];
        }
        if (defaultImage) {
            self.image = [self correctForRotation:defaultImage];
            [self createImageStamp];
        }
    }

    // Tap handled.
    return YES;
}

-(void)createImageStamp
{
    BOOL hasWriteLock = NO;

    @try {
        [self.pdfViewCtrl DocLock:YES];
        hasWriteLock = YES;

        PTPDFDoc *doc = [self.pdfViewCtrl GetDoc];
        
        PTPage* page = [doc GetPage:self.pageNumber];
        PTPDFRect* stampRect = [[PTPDFRect alloc] initWithX1:0 y1:0 x2:self.image.size.width y2:self.image.size.height];
        double maxWidth = 25.0;
        double maxHeight = 25.0;

        PTRotate ctrlRotation = [self.pdfViewCtrl GetRotation];
        PTRotate pageRotation = [page GetRotation];
        PTRotate viewRotation = ((pageRotation + ctrlRotation) % 4);

        if ([page GetPageWidth:(e_ptcrop)] < maxWidth)
        {
            maxWidth = [page GetPageWidth:(e_ptcrop)];
        }
        if ([page GetPageHeight:(e_ptcrop)] < maxHeight)
        {
            maxHeight = [page GetPageHeight:(e_ptcrop)];
        }

        if (viewRotation == e_pt90 || viewRotation == e_pt270) {
            // Swap width and height if visible page is rotated 90 or 270 degrees
            maxWidth = maxWidth + maxHeight;
            maxHeight = maxWidth - maxHeight;
            maxWidth = maxWidth - maxHeight;
        }

        CGFloat scaleFactor = MIN(maxWidth / [stampRect Width], maxHeight / [stampRect Height]);
        CGFloat stampWidth = [stampRect Width] * scaleFactor;
        CGFloat stampHeight = [stampRect Height] * scaleFactor;

        if (ctrlRotation == e_pt90 || ctrlRotation == e_pt270) {
            // Swap width and height if pdfViewCtrl is rotated 90 or 270 degrees
            stampWidth = stampWidth + stampHeight;
            stampHeight = stampWidth - stampHeight;
            stampWidth = stampWidth - stampHeight;
        }

        PTStamper* stamper = [[PTStamper alloc] initWithSize_type:e_ptabsolute_size a:stampWidth b:stampHeight];
        [stamper SetAlignment:e_pthorizontal_left vertical_alignment:e_ptvertical_bottom];
        [stamper SetAsAnnotation:YES];

        // Account for page rotation in the page-space touch point
        PTMatrix2D *mtx = [page GetDefaultMatrix:NO box_type:e_ptcrop angle:0];
        self.touchPtPage = [mtx Mult:self.touchPtPage];

        CGFloat xPos = [self.touchPtPage getX] - (stampWidth / 2);
        CGFloat yPos = [self.touchPtPage getY] - (stampHeight / 2);

        double pageWidth = [page GetPageWidth:(e_ptcrop)];
        if (xPos > pageWidth - stampWidth)
        {
            xPos = pageWidth - stampWidth;
        }
        if (xPos < 0)
        {
            xPos = 0;
        }
        double pageHeight = [page GetPageHeight:(e_ptcrop)];
        if (yPos > pageHeight - stampHeight)
        {
            yPos = pageHeight - stampHeight;
        }
        if (yPos < 0)
        {
            yPos = 0;
        }

        [stamper SetPosition:xPos vertical_distance:yPos use_percentage:NO];

        PTPageSet* pageSet = [[PTPageSet alloc] initWithOne_page:self.pageNumber];

        NSData* data = UIImagePNGRepresentation(self.image);

        PTObjSet* hintSet = [[PTObjSet alloc] init];
        PTObj* encoderHints = [hintSet CreateArray];
        [encoderHints PushBackName:@"Flate"];
        [encoderHints PushBackName:@"Level"];
        [encoderHints PushBackNumber:9.0];

        PTImage* stampImage = [PTImage CreateWithDataSimple:[doc GetSDFDoc] buf:data buf_size:data.length encoder_hints:encoderHints];

        // Rotate stamp based on the pdfViewCtrl's rotation
        PTRotate stampRotation = (4 - ctrlRotation) % 4; // 0 = 0, 90 = 1; 180 = 2, and 270 = 3
        if ([page GetPageWidth:(e_ptcrop)] == [[page GetCropBox] Height] && [page GetPageHeight:(e_ptcrop)] == [[page GetCropBox] Width]) {
            stampRotation = (4 - ctrlRotation - 1) % 4;
        }

        [stamper SetRotation:stampRotation * 90.0];
        [stamper StampImage:doc src_img:stampImage dest_pages:pageSet];

        int numAnnots = [page GetNumAnnots];

        assert(numAnnots > 0);

        PTAnnot* annot = [page GetAnnot:numAnnots - 1];
        PTObj* obj = [annot GetSDFObj];
        [obj PutString:PTImageStampAnnotationIdentifier value:@""];
        [obj PutNumber:PTImageStampAnnotationRotationDegreeIdentifier value:0.0];

        // Set up to transfer to PTAnnotEditTool
        self.currentAnnotation = annot;
        [self.currentAnnotation RefreshAppearance];

        self.annotationPageNumber = self.pageNumber;

        [self.pdfViewCtrl UpdateWithAnnot:annot page_num:self.pageNumber];

    } @catch (NSException *exception) {
        NSLog(@"Exception: %@, %@", exception.name, exception.reason);
    } @finally {
        if (hasWriteLock) {
            [self.pdfViewCtrl DocUnlock];
        }
    }

    if (self.currentAnnotation && self.annotationPageNumber > 0) {
        [self annotationAdded:self.currentAnnotation onPageNumber:self.annotationPageNumber];
    }
}

-(UIImage*)correctForRotation:(UIImage*)src
{
    UIGraphicsBeginImageContext(src.size);

    [src drawAtPoint:CGPointMake(0, 0)];

    UIImage* img =  UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();

    return img;
}

@end

#pragma mark - BauhubPlusIconTool
@interface BauhubPlusIconTool () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate>

@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, nullable) PTPDFPoint *touchPtPage;
@property (nonatomic, assign) BOOL isPencilTouch;

@end

@implementation BauhubPlusIconTool

@dynamic isPencilTouch;

- (Class)annotClass
{
    return [PTRubberStamp class];
}

+ (PTExtendedAnnotType)annotType
{
    return PTExtendedAnnotTypeImageStamp;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl handleTap:(UITapGestureRecognizer *)gestureRecognizer
{

    if( !(self.isPencilTouch == YES || self.toolManager.annotationsCreatedWithPencilOnly == NO) )
    {
        return YES;
    }

    CGPoint touchPoint = [gestureRecognizer locationInView:self.pdfViewCtrl];

    int pageNumber = [self.pdfViewCtrl GetPageNumberFromScreenPt:touchPoint.x y:touchPoint.y];
    if (pageNumber < 1) {
        return YES;
    }
    // Save page number for touch point.
    _pageNumber = pageNumber;
    self.endPoint = touchPoint;
    self.touchPtPage = [self.pdfViewCtrl ConvScreenPtToPagePt:[[PTPDFPoint alloc] initWithPx:self.endPoint.x py:self.endPoint.y] page_num:_pageNumber];

    UIImage *rawImage = [UIImage imageNamed:@"bauhubPlusIconTool"];
    
    if (rawImage) {
        self.image = [self correctForRotation:rawImage];
        [self createImageStamp];
    }
    
    // Tap handled.
    return YES;
}

-(void)createImageStamp
{
    BOOL hasWriteLock = NO;

    @try {
        [self.pdfViewCtrl DocLock:YES];
        hasWriteLock = YES;

        PTPDFDoc *doc = [self.pdfViewCtrl GetDoc];
        
        PTPage* page = [doc GetPage:self.pageNumber];
        PTPDFRect* stampRect = [[PTPDFRect alloc] initWithX1:0 y1:0 x2:self.image.size.width y2:self.image.size.height];
        double maxWidth = 25.0;
        double maxHeight = 25.0;

        PTRotate ctrlRotation = [self.pdfViewCtrl GetRotation];
        PTRotate pageRotation = [page GetRotation];
        PTRotate viewRotation = ((pageRotation + ctrlRotation) % 4);

        if ([page GetPageWidth:(e_ptcrop)] < maxWidth)
        {
            maxWidth = [page GetPageWidth:(e_ptcrop)];
        }
        if ([page GetPageHeight:(e_ptcrop)] < maxHeight)
        {
            maxHeight = [page GetPageHeight:(e_ptcrop)];
        }

        if (viewRotation == e_pt90 || viewRotation == e_pt270) {
            // Swap width and height if visible page is rotated 90 or 270 degrees
            maxWidth = maxWidth + maxHeight;
            maxHeight = maxWidth - maxHeight;
            maxWidth = maxWidth - maxHeight;
        }

        CGFloat scaleFactor = MIN(maxWidth / [stampRect Width], maxHeight / [stampRect Height]);
        CGFloat stampWidth = [stampRect Width] * scaleFactor;
        CGFloat stampHeight = [stampRect Height] * scaleFactor;

        if (ctrlRotation == e_pt90 || ctrlRotation == e_pt270) {
            // Swap width and height if pdfViewCtrl is rotated 90 or 270 degrees
            stampWidth = stampWidth + stampHeight;
            stampHeight = stampWidth - stampHeight;
            stampWidth = stampWidth - stampHeight;
        }

        PTStamper* stamper = [[PTStamper alloc] initWithSize_type:e_ptabsolute_size a:stampWidth b:stampHeight];
        [stamper SetAlignment:e_pthorizontal_left vertical_alignment:e_ptvertical_bottom];
        [stamper SetAsAnnotation:YES];

        // Account for page rotation in the page-space touch point
        PTMatrix2D *mtx = [page GetDefaultMatrix:NO box_type:e_ptcrop angle:0];
        self.touchPtPage = [mtx Mult:self.touchPtPage];

        CGFloat xPos = [self.touchPtPage getX] - (stampWidth / 2);
        CGFloat yPos = [self.touchPtPage getY] - (stampHeight / 2);

        double pageWidth = [page GetPageWidth:(e_ptcrop)];
        if (xPos > pageWidth - stampWidth)
        {
            xPos = pageWidth - stampWidth;
        }
        if (xPos < 0)
        {
            xPos = 0;
        }
        double pageHeight = [page GetPageHeight:(e_ptcrop)];
        if (yPos > pageHeight - stampHeight)
        {
            yPos = pageHeight - stampHeight;
        }
        if (yPos < 0)
        {
            yPos = 0;
        }

        [stamper SetPosition:xPos vertical_distance:yPos use_percentage:NO];

        PTPageSet* pageSet = [[PTPageSet alloc] initWithOne_page:self.pageNumber];

        NSData* data = UIImagePNGRepresentation(self.image);

        PTObjSet* hintSet = [[PTObjSet alloc] init];
        PTObj* encoderHints = [hintSet CreateArray];
        [encoderHints PushBackName:@"Flate"];
        [encoderHints PushBackName:@"Level"];
        [encoderHints PushBackNumber:9.0];

        PTImage* stampImage = [PTImage CreateWithDataSimple:[doc GetSDFDoc] buf:data buf_size:data.length encoder_hints:encoderHints];

        // Rotate stamp based on the pdfViewCtrl's rotation
        PTRotate stampRotation = (4 - ctrlRotation) % 4; // 0 = 0, 90 = 1; 180 = 2, and 270 = 3
        [stamper SetRotation:stampRotation * 90.0];
        [stamper StampImage:doc src_img:stampImage dest_pages:pageSet];

        int numAnnots = [page GetNumAnnots];

        assert(numAnnots > 0);

        PTAnnot* annot = [page GetAnnot:numAnnots - 1];
        PTObj* obj = [annot GetSDFObj];
        [obj PutString:PTImageStampAnnotationIdentifier value:@""];
        [obj PutNumber:PTImageStampAnnotationRotationDegreeIdentifier value:0.0];

        // Set up to transfer to PTAnnotEditTool
        self.currentAnnotation = annot;
        [self.currentAnnotation RefreshAppearance];

        self.annotationPageNumber = self.pageNumber;

        [self.pdfViewCtrl UpdateWithAnnot:annot page_num:self.pageNumber];

    } @catch (NSException *exception) {
        NSLog(@"Exception: %@, %@", exception.name, exception.reason);
    } @finally {
        if (hasWriteLock) {
            [self.pdfViewCtrl DocUnlock];
        }
    }

    if (self.currentAnnotation && self.annotationPageNumber > 0) {
        [self annotationAdded:self.currentAnnotation onPageNumber:self.annotationPageNumber];
    }
}

-(UIImage*)correctForRotation:(UIImage*)src
{
    UIGraphicsBeginImageContext(src.size);

    [src drawAtPoint:CGPointMake(0, 0)];

    UIImage* img =  UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();

    return img;
}

@end

#pragma mark - BauhubPinStampTool
@interface BauhubPinStampTool () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate>

@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, nullable) PTPDFPoint *touchPtPage;
@property (nonatomic, assign) BOOL isPencilTouch;

@end

@implementation BauhubPinStampTool

@dynamic isPencilTouch;

- (Class)annotClass
{
    return [PTRubberStamp class];
}

+ (PTExtendedAnnotType)annotType
{
    return PTExtendedAnnotTypeImageStamp;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl handleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    if( !(self.isPencilTouch == YES || self.toolManager.annotationsCreatedWithPencilOnly == NO) )
    {
        return YES;
    }

    CGPoint touchPoint = [gestureRecognizer locationInView:self.pdfViewCtrl];

    int pageNumber = [self.pdfViewCtrl GetPageNumberFromScreenPt:touchPoint.x y:touchPoint.y];
    if (pageNumber < 1) {
        return YES;
    }
    _pageNumber = pageNumber;
    self.endPoint = touchPoint;
    self.touchPtPage = [self.pdfViewCtrl ConvScreenPtToPagePt:[[PTPDFPoint alloc] initWithPx:self.endPoint.x py:self.endPoint.y] page_num:_pageNumber];

    NSString *imgName = (self.pinImageName != nil && self.pinImageName.length > 0) ? self.pinImageName : @"bauhubCommentPin";
    UIImage *rawImage = BauhubLoadTemplateImageNamed(imgName);
    // Runner sometimes omits bauhubAttachmentPin from the asset catalog; still create a stamp so Flutter gets annotationChanged.
    if (!rawImage && [imgName isEqualToString:@"bauhubAttachmentPin"]) {
        rawImage = BauhubLoadTemplateImageNamed(@"bauhubCommentPin");
        if (rawImage) {
            NSLog(@"BauhubPinStampTool: bauhubAttachmentPin not found in bundle, using bauhubCommentPin (subject remains Attachment)");
        }
    }
    if (rawImage) {
        self.image = [self correctForRotation:rawImage];
        [self createImageStamp];
    } else {
        NSLog(@"BauhubPinStampTool: no image for '%@' — stamp not created", imgName);
    }

    return YES;
}

-(void)createImageStamp
{
    BOOL hasWriteLock = NO;

    @try {
        [self.pdfViewCtrl DocLock:YES];
        hasWriteLock = YES;

        PTPDFDoc *doc = [self.pdfViewCtrl GetDoc];
        PTPage* page = [doc GetPage:self.pageNumber];
        PTPDFRect* stampRect = [[PTPDFRect alloc] initWithX1:0 y1:0 x2:self.image.size.width y2:self.image.size.height];
        double maxWidth = 25.0;
        double maxHeight = 25.0;

        PTRotate ctrlRotation = [self.pdfViewCtrl GetRotation];
        PTRotate pageRotation = [page GetRotation];
        PTRotate viewRotation = ((pageRotation + ctrlRotation) % 4);

        if ([page GetPageWidth:(e_ptcrop)] < maxWidth)
        {
            maxWidth = [page GetPageWidth:(e_ptcrop)];
        }
        if ([page GetPageHeight:(e_ptcrop)] < maxHeight)
        {
            maxHeight = [page GetPageHeight:(e_ptcrop)];
        }

        if (viewRotation == e_pt90 || viewRotation == e_pt270) {
            maxWidth = maxWidth + maxHeight;
            maxHeight = maxWidth - maxHeight;
            maxWidth = maxWidth - maxHeight;
        }

        CGFloat scaleFactor = MIN(maxWidth / [stampRect Width], maxHeight / [stampRect Height]);
        CGFloat stampWidth = [stampRect Width] * scaleFactor;
        CGFloat stampHeight = [stampRect Height] * scaleFactor;

        if (ctrlRotation == e_pt90 || ctrlRotation == e_pt270) {
            stampWidth = stampWidth + stampHeight;
            stampHeight = stampWidth - stampHeight;
            stampWidth = stampWidth - stampHeight;
        }

        PTStamper* stamper = [[PTStamper alloc] initWithSize_type:e_ptabsolute_size a:stampWidth b:stampHeight];
        [stamper SetAlignment:e_pthorizontal_left vertical_alignment:e_ptvertical_bottom];
        [stamper SetAsAnnotation:YES];

        PTMatrix2D *mtx = [page GetDefaultMatrix:NO box_type:e_ptcrop angle:0];
        self.touchPtPage = [mtx Mult:self.touchPtPage];

        CGFloat xPos = [self.touchPtPage getX] - (stampWidth / 2);
        CGFloat yPos = [self.touchPtPage getY] - (stampHeight / 2);

        double pageWidth = [page GetPageWidth:(e_ptcrop)];
        if (xPos > pageWidth - stampWidth) { xPos = pageWidth - stampWidth; }
        if (xPos < 0) { xPos = 0; }
        double pageHeight = [page GetPageHeight:(e_ptcrop)];
        if (yPos > pageHeight - stampHeight) { yPos = pageHeight - stampHeight; }
        if (yPos < 0) { yPos = 0; }

        [stamper SetPosition:xPos vertical_distance:yPos use_percentage:NO];

        PTPageSet* pageSet = [[PTPageSet alloc] initWithOne_page:self.pageNumber];

        NSData* data = UIImagePNGRepresentation(self.image);

        PTObjSet* hintSet = [[PTObjSet alloc] init];
        PTObj* encoderHints = [hintSet CreateArray];
        [encoderHints PushBackName:@"Flate"];
        [encoderHints PushBackName:@"Level"];
        [encoderHints PushBackNumber:9.0];

        PTImage* stampImage = [PTImage CreateWithDataSimple:[doc GetSDFDoc] buf:data buf_size:data.length encoder_hints:encoderHints];

        PTRotate stampRotation = (4 - ctrlRotation) % 4;
        [stamper SetRotation:stampRotation * 90.0];
        [stamper StampImage:doc src_img:stampImage dest_pages:pageSet];

        int numAnnots = [page GetNumAnnots];
        assert(numAnnots > 0);

        PTAnnot* annot = [page GetAnnot:numAnnots - 1];
        PTObj* obj = [annot GetSDFObj];
        [obj PutString:PTImageStampAnnotationIdentifier value:@""];
        [obj PutNumber:PTImageStampAnnotationRotationDegreeIdentifier value:0.0];

        NSString *subject = (self.pinSubject != nil && self.pinSubject.length > 0) ? self.pinSubject : @"Comment";
        PTMarkup *markupAnnot = [[PTMarkup alloc] initWithAnn:annot];
        if ([markupAnnot IsValid]) {
            [markupAnnot SetSubject:subject];
        }

        // Match WebViewer XFDF: flags="print,nozoom,norotate" + local-timezone dates.
        BauhubApplyWebStyleStampFlagsAndDates(annot);

        self.currentAnnotation = annot;
        [self.currentAnnotation RefreshAppearance];

        self.annotationPageNumber = self.pageNumber;

        [self.pdfViewCtrl UpdateWithAnnot:annot page_num:self.pageNumber];

    } @catch (NSException *exception) {
        NSLog(@"Exception: %@, %@", exception.name, exception.reason);
    } @finally {
        if (hasWriteLock) {
            [self.pdfViewCtrl DocUnlock];
        }
    }

    if (self.currentAnnotation && self.annotationPageNumber > 0) {
        [self annotationAdded:self.currentAnnotation onPageNumber:self.annotationPageNumber];
    }
    // Apryse iOS Tools: backToDefaultTool was removed; switch explicitly to pan (same as Flutter setToolMode @"" / "Pan").
    if (self.toolManager != nil) {
        [self.toolManager changeTool:[PTPanTool class]];
    }
}

-(UIImage*)correctForRotation:(UIImage*)src
{
    UIGraphicsBeginImageContext(src.size);
    [src drawAtPoint:CGPointMake(0, 0)];
    UIImage* img =  UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end

#pragma mark - Bauhub WebViewer-style XFDF alignment (dates + stamp flags)

/**
 * Aligns Bauhub mobile XFDF output with WebViewer:
 *
 *   - dates ("M", "CreationDate") use a local-timezone PDF Date string
 *     (e.g. "D:20260529101309+03'00'") instead of UTC ("D:20260529065415Z");
 *   - stamps (point pins + decorative area pins) carry flags="print,nozoom,norotate" so the icons
 *     stay fixed-size and upright at any zoom/rotation (matches WebViewer; mobile previously
 *     emitted only "print" and faked no-zoom for decorative pins via a manual rect resize).
 *
 * Square / polygon area markups keep PDFTron-default flags ("print") — web emits the same — so
 * only date alignment is applied for those.
 */
static NSString *BauhubBuildLocalPdfDateString(NSDate *date)
{
    if (date == nil) {
        date = [NSDate date];
    }
    NSTimeZone *tz = [NSTimeZone localTimeZone];
    NSInteger offsetSec = [tz secondsFromGMTForDate:date];
    char sign = offsetSec >= 0 ? '+' : '-';
    NSInteger absMin = labs((long)offsetSec) / 60;
    NSInteger offHrs = absMin / 60;
    NSInteger offMin = absMin % 60;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.timeZone = tz;
    fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    fmt.dateFormat = @"yyyyMMddHHmmss";
    NSString *base = [fmt stringFromDate:date];
    return [NSString stringWithFormat:@"D:%@%c%02ld'%02ld'", base, sign, (long)offHrs, (long)offMin];
}

static void BauhubWriteLocalCreationAndModDatesOnAnnot(PTAnnot *annot)
{
    if (annot == nil || ![annot IsValid]) {
        return;
    }
    @try {
        PTObj *sdf = [annot GetSDFObj];
        if (sdf == nil || ![sdf IsValid]) {
            return;
        }
        NSString *pdfDate = BauhubBuildLocalPdfDateString([NSDate date]);
        [sdf PutString:@"M" value:pdfDate];
        [sdf PutString:@"CreationDate" value:pdfDate];
    } @catch (__unused NSException *e) {
    }
}

static void BauhubApplyWebStyleStampFlagsAndDates(PTAnnot *stampAnnot)
{
    if (stampAnnot == nil || ![stampAnnot IsValid]) {
        return;
    }
    @try {
        // PTAnnot iOS enum is e_ptprint_annot (Android uses Annot.e_print) — see existing usage
        // in setFlagsForAnnotations around line 2890.
        [stampAnnot SetFlag:e_ptprint_annot value:YES];
        [stampAnnot SetFlag:e_ptno_zoom value:YES];
        [stampAnnot SetFlag:e_ptno_rotate value:YES];
    } @catch (__unused NSException *e) {
    }
    BauhubWriteLocalCreationAndModDatesOnAnnot(stampAnnot);
}

static void BauhubApplyWebStyleShapeDates(PTAnnot *shapeAnnot)
{
    BauhubWriteLocalCreationAndModDatesOnAnnot(shapeAnnot);
}

#pragma mark - Bauhub area pin on Comment / Attachment squares & polygons

static NSString * const kBauhubAreaPinCustomKey = @"BauhubAreaPin";
static NSString * const kBauhubDecorativeAreaPinKey = @"BauhubDecorativeAreaPin";
static NSString * const kBauhubParentShapeUidKey = @"BauhubParentShapeUid";
/// Fixed PDF corner when resizing (left = min x, top = max y), same as web pin box top-left in page space.
static NSString * const kBauhubPinPageAx = @"BauhubPinPageAx";
static NSString * const kBauhubPinPageAy = @"BauhubPinPageAy";

void PTBauhubRemoveDecorativePinsWhenParentShapeRemoved(
        PTPDFViewCtrl *pdfViewCtrl,
        PTPDFDoc *doc,
        PTAnnot *shapeAnnot,
        int pageNumber) {
    if (!pdfViewCtrl || !doc || !shapeAnnot || ![shapeAnnot IsValid]) {
        return;
    }
    PTAnnotType t = [shapeAnnot GetType];
    if (t != e_ptSquare && t != e_ptPolygon) {
        return;
    }
    PTMarkup *mk = [[PTMarkup alloc] initWithAnn:shapeAnnot];
    if (![mk IsValid]) {
        return;
    }
    NSString *subj = [mk GetSubject];
    if (!([subj isEqualToString:@"Comment"] || [subj isEqualToString:@"Attachment"] ||
          [subj isEqualToString:@"Task"])) {
        return;
    }
    NSString *parentUid = nil;
    @try {
        PTObj *uidObj = [shapeAnnot GetUniqueID];
        if ([uidObj IsValid] && [uidObj IsString]) {
            parentUid = [uidObj GetAsPDFText];
        }
    } @catch (__unused NSException *e) {
    }
    if (parentUid.length == 0) {
        return;
    }
    if (pageNumber < 1) {
        return;
    }
    PTPage *page = [doc GetPage:pageNumber];
    if (!page || ![page IsValid]) {
        return;
    }
    NSMutableArray<PTAnnot *> *toRemove = [NSMutableArray array];
    int n = (int)[page GetNumAnnots];
    for (int i = 0; i < n; i++) {
        PTAnnot *a = [page GetAnnot:i];
        if (![a IsValid] || [a GetType] != e_ptStamp) {
            continue;
        }
        NSString *dec = nil;
        @try {
            dec = [a GetCustomData:kBauhubDecorativeAreaPinKey];
        } @catch (__unused NSException *e) {
        }
        if (dec.length == 0) {
            continue;
        }
        NSString *puid = nil;
        @try {
            puid = [a GetCustomData:kBauhubParentShapeUidKey];
        } @catch (__unused NSException *e) {
        }
        if (puid != nil && [puid isEqualToString:parentUid]) {
            [toRemove addObject:a];
        }
    }
    for (PTAnnot *st in toRemove) {
        @try {
            [page AnnotRemoveWithAnnot:st];
        } @catch (__unused NSException *e) {
        }
    }
    if (toRemove.count > 0) {
        [pdfViewCtrl Update:YES];
    }
}

void PTBauhubRepositionDecorativePinWhenParentShapeMoved(
        PTPDFViewCtrl *pdfViewCtrl,
        PTPDFDoc *doc,
        PTAnnot *shapeAnnot,
        int pageNumber) {
    if (!pdfViewCtrl || !doc || !shapeAnnot || ![shapeAnnot IsValid]) {
        return;
    }
    PTAnnotType t = [shapeAnnot GetType];
    if (t != e_ptSquare && t != e_ptPolygon) {
        return;
    }
    PTMarkup *mk = [[PTMarkup alloc] initWithAnn:shapeAnnot];
    if (![mk IsValid]) {
        return;
    }
    NSString *subj = [mk GetSubject];
    if (!([subj isEqualToString:@"Comment"] || [subj isEqualToString:@"Attachment"] ||
          [subj isEqualToString:@"Task"])) {
        return;
    }
    NSString *parentUid = nil;
    @try {
        PTObj *uidObj = [shapeAnnot GetUniqueID];
        if ([uidObj IsValid] && [uidObj IsString]) {
            parentUid = [uidObj GetAsPDFText];
        }
    } @catch (__unused NSException *e) {
    }
    if (parentUid.length == 0) {
        return;
    }
    if (pageNumber < 1) {
        pageNumber = BauhubFindPageNumberForAnnotInDoc(doc, shapeAnnot);
    }
    if (pageNumber < 1) {
        return;
    }
    PTPage *page = [doc GetPage:pageNumber];
    if (!page || ![page IsValid]) {
        return;
    }
    PTPDFRect *bbox = [shapeAnnot GetRect];
    double newAx = MIN([bbox GetX1], [bbox GetX2]) + 4.0;
    double newAy = MAX([bbox GetY1], [bbox GetY2]) - 4.0;
    int n = (int)[page GetNumAnnots];
    for (int i = 0; i < n; i++) {
        PTAnnot *a = [page GetAnnot:i];
        if (![a IsValid] || [a GetType] != e_ptStamp) {
            continue;
        }
        NSString *dec = nil;
        @try {
            dec = [a GetCustomData:kBauhubDecorativeAreaPinKey];
        } @catch (__unused NSException *e) {
        }
        if (dec.length == 0) {
            continue;
        }
        NSString *puid = nil;
        @try {
            puid = [a GetCustomData:kBauhubParentShapeUidKey];
        } @catch (__unused NSException *e) {
        }
        if (puid == nil || ![puid isEqualToString:parentUid]) {
            continue;
        }
        PTPDFRect *r = [a GetRect];
        double spanW = fabs([r GetX2] - [r GetX1]);
        double spanH = fabs([r GetY2] - [r GetY1]);
        if (spanW < 0.5) {
            spanW = 0.5;
        }
        if (spanH < 0.5) {
            spanH = 0.5;
        }
        PTPDFRect *newRect = [[PTPDFRect alloc] initWithX1:newAx y1:newAy - spanH x2:newAx + spanW y2:newAy];
        [a SetRect:newRect];
        @try {
            [a SetCustomData:kBauhubPinPageAx value:[NSString stringWithFormat:@"%.8f", newAx]];
            [a SetCustomData:kBauhubPinPageAy value:[NSString stringWithFormat:@"%.8f", newAy]];
        } @catch (__unused NSException *e) {
        }
        [pdfViewCtrl UpdateWithAnnot:a page_num:pageNumber];
        break;
    }
    [pdfViewCtrl UpdateWithAnnot:shapeAnnot page_num:pageNumber];
}

void PTBauhubSetDecorativePinsVisibilityForParentShape(
        PTPDFViewCtrl *pdfViewCtrl,
        PTPDFDoc *doc,
        PTAnnot *shapeAnnot,
        int pageNumber,
        BOOL visible) {
    if (!pdfViewCtrl || !doc || !shapeAnnot || ![shapeAnnot IsValid]) {
        return;
    }
    PTAnnotType t = [shapeAnnot GetType];
    if (t != e_ptSquare && t != e_ptPolygon) {
        return;
    }
    PTMarkup *mk = [[PTMarkup alloc] initWithAnn:shapeAnnot];
    if (![mk IsValid]) {
        return;
    }
    NSString *subj = [mk GetSubject];
    if (!([subj isEqualToString:@"Comment"] || [subj isEqualToString:@"Attachment"] ||
          [subj isEqualToString:@"Task"])) {
        return;
    }
    NSString *parentUid = nil;
    @try {
        PTObj *uidObj = [shapeAnnot GetUniqueID];
        if ([uidObj IsValid] && [uidObj IsString]) {
            parentUid = [uidObj GetAsPDFText];
        }
    } @catch (__unused NSException *e) {
    }
    if (parentUid.length == 0) {
        return;
    }
    if (pageNumber < 1) {
        pageNumber = BauhubFindPageNumberForAnnotInDoc(doc, shapeAnnot);
    }
    if (pageNumber < 1) {
        return;
    }
    PTPage *page = [doc GetPage:pageNumber];
    if (!page || ![page IsValid]) {
        return;
    }
    int n = (int)[page GetNumAnnots];
    for (int i = 0; i < n; i++) {
        PTAnnot *a = [page GetAnnot:i];
        if (![a IsValid] || [a GetType] != e_ptStamp) {
            continue;
        }
        NSString *dec = nil;
        @try {
            dec = [a GetCustomData:kBauhubDecorativeAreaPinKey];
        } @catch (__unused NSException *e) {
        }
        if (dec.length == 0) {
            continue;
        }
        NSString *puid = nil;
        @try {
            puid = [a GetCustomData:kBauhubParentShapeUidKey];
        } @catch (__unused NSException *e) {
        }
        if (puid == nil || ![puid isEqualToString:parentUid]) {
            continue;
        }
        if (visible) {
            [pdfViewCtrl ShowAnnotation:a];
        } else {
            [pdfViewCtrl HideAnnotation:a];
        }
    }
}

/// Flutter may send ARGB as NSNumber (incl. double/long long) or string; returns NO if absent/unsupported (0xFFFFFFFF white is valid).
static BOOL BauhubTryUint32FromFlutterColorArg(id value, NSUInteger *outArgb) {
    if (value == nil || value == [NSNull null] || outArgb == NULL) {
        return NO;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *n = (NSNumber *)value;
        // Match Android PluginUtils: preserve low 32 bits (ARGB may arrive as signed int or double).
        long long ll = [n longLongValue];
        *outArgb = (NSUInteger)((uint32_t)ll);
        return YES;
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (s.length == 0) {
            return NO;
        }
        const char *c = [s UTF8String];
        char *end = NULL;
        unsigned long parsed = strtoul(c, &end, 0);
        if (end == c) {
            return NO;
        }
        *outArgb = (NSUInteger)(parsed & 0xFFFFFFFFULL);
        return YES;
    }
    return NO;
}

/// Matches bauhub-fe PdfTronTools.ts taskPinColor #DD1111 (not category color). Prefer task_dd1111 in bundle.
static UIImage *BauhubLoadTemplateImageNamed(NSString *name) {
    if (name.length == 0) {
        return nil;
    }
    UIImage *img = [UIImage imageNamed:name];
    if (img) {
        return img;
    }
    NSBundle *pluginBundle = [NSBundle bundleForClass:[PdftronFlutterPlugin class]];
    img = [UIImage imageNamed:name inBundle:pluginBundle compatibleWithTraitCollection:nil];
    if (img) {
        return img;
    }
    return [UIImage imageNamed:name inBundle:[NSBundle mainBundle] compatibleWithTraitCollection:nil];
}

static NSString *BauhubWebTaskPinImageName(void) {
    UIImage *dd = BauhubLoadTemplateImageNamed(@"task_dd1111");
    return dd != nil ? @"task_dd1111" : @"task_111111";
}

static UIImage *BauhubAreaPinCorrectImage(UIImage *src) {
    if (!src) {
        return nil;
    }
    UIGraphicsBeginImageContext(src.size);
    [src drawAtPoint:CGPointMake(0, 0)];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

static BOOL BauhubAnnotShouldReceiveAreaPin(PTAnnot *annot) {
    if (![annot IsValid]) {
        return NO;
    }
    PTAnnotType t = [annot GetType];
    if (t != e_ptSquare && t != e_ptPolygon) {
        return NO;
    }
    PTMarkup *m = [[PTMarkup alloc] initWithAnn:annot];
    if (![m IsValid]) {
        return NO;
    }
    NSString *subj = [m GetSubject];
    return [subj isEqualToString:@"Comment"] || [subj isEqualToString:@"Attachment"] || [subj isEqualToString:@"Task"];
}

static BOOL BauhubPageHasPinStampNearShapeCorner(PTPage *page, PTPDFRect *bbox, NSString *subject) {
    if (!page || subject.length == 0) {
        return NO;
    }
    double x1 = [bbox GetX1], y1 = [bbox GetY1], x2 = [bbox GetX2], y2 = [bbox GetY2];
    double minX = MIN(x1, x2);
    double maxY = MAX(y1, y2);
    double targetX = minX + 4.0 + 12.0;
    double targetY = maxY - 4.0 - 12.0;
    int n = [page GetNumAnnots];
    for (int i = 0; i < n; i++) {
        PTAnnot *a = [page GetAnnot:i];
        if (![a IsValid] || [a GetType] != e_ptStamp) {
            continue;
        }
        NSString *dec = nil;
        @try {
            dec = [a GetCustomData:kBauhubDecorativeAreaPinKey];
        } @catch (__unused NSException *e) {
            dec = nil;
        }
        PTPDFRect *r = [a GetRect];
        double cx = ([r GetX1] + [r GetX2]) / 2.0;
        double cy = ([r GetY1] + [r GetY2]) / 2.0;
        double dx = cx - targetX;
        double dy = cy - targetY;
        if (sqrt(dx * dx + dy * dy) >= 40.0) {
            continue;
        }
        // Only decorative area pins count — a normal Comment/Attachment *point* stamp nearby used to match here and skip stamping.
        if (dec != nil && dec.length > 0) {
            return YES;
        }
    }
    return NO;
}

/// Locate which page contains this annot (currentPage is often 0 while RectangleCreate finishes).
static int BauhubFindPageNumberForAnnotInDoc(PTPDFDoc *doc, PTAnnot *target) {
    if (!doc || !target || ![target IsValid]) {
        return -1;
    }
    PTObj *targetObj = [target GetSDFObj];
    if (![targetObj IsValid]) {
        return -1;
    }
    int targetNum = (int)[targetObj GetObjNum];
    int targetGen = (int)[targetObj GetGenNum];
    int pageCount = (int)[doc GetPageCount];
    for (int p = 1; p <= pageCount; p++) {
        PTPage *page = [doc GetPage:p];
        if (!page || ![page IsValid]) {
            continue;
        }
        int n = [page GetNumAnnots];
        for (int j = 0; j < n; j++) {
            PTAnnot *a = [page GetAnnot:j];
            if (![a IsValid]) {
                continue;
            }
            PTObj *o = [a GetSDFObj];
            if ([o IsValid] && (int)[o GetObjNum] == targetNum && (int)[o GetGenNum] == targetGen) {
                return p;
            }
        }
    }
    return -1;
}

static void BauhubStampPinForAreaShapeImpl(PTPDFViewCtrl *pdfViewCtrl, PTPDFDoc *doc, int pageNumber, PTAnnot *shapeAnnot, BOOL allowDeferredRetry);

/// Caller must hold a write lock on the document (same as Bauhub pin stamper paths).
static void BauhubStampPinForAreaShape(PTPDFViewCtrl *pdfViewCtrl, PTPDFDoc *doc, int pageNumber, PTAnnot *shapeAnnot) {
    BauhubStampPinForAreaShapeImpl(pdfViewCtrl, doc, pageNumber, shapeAnnot, YES);
}

static void BauhubStampPinForAreaShapeImpl(PTPDFViewCtrl *pdfViewCtrl, PTPDFDoc *doc, int pageNumber, PTAnnot *shapeAnnot, BOOL allowDeferredRetry) {
    if (!pdfViewCtrl || !doc || ![shapeAnnot IsValid]) {
        return;
    }
    if (!BauhubAnnotShouldReceiveAreaPin(shapeAnnot)) {
        return;
    }

    int pnum = BauhubFindPageNumberForAnnotInDoc(doc, shapeAnnot);
    if (pnum < 1) {
        pnum = pageNumber;
    }
    if (pnum < 1) {
        pnum = (int)pdfViewCtrl.currentPage;
    }
    if (pnum < 1) {
        if (allowDeferredRetry) {
            __weak PTPDFViewCtrl *weakCtrl = pdfViewCtrl;
            __weak PTPDFDoc *weakDoc = doc;
            __weak PTAnnot *weakAnnot = shapeAnnot;
            dispatch_async(dispatch_get_main_queue(), ^{
                PTPDFViewCtrl *c = weakCtrl;
                PTPDFDoc *d = weakDoc;
                PTAnnot *a = weakAnnot;
                if (!c || !d || ![a IsValid]) {
                    return;
                }
                int cp = (int)c.currentPage;
                if (cp < 1) {
                    cp = BauhubFindPageNumberForAnnotInDoc(d, a);
                }
                if (cp < 1) {
                    return;
                }
                BauhubStampPinForAreaShapeImpl(c, d, cp, a, NO);
            });
        }
        return;
    }

    int pageCount = [doc GetPageCount];
    if (pageCount < 1) {
        return;
    }
    if (pnum > pageCount) {
        pnum = pageCount;
    }

    PTPage *page = [doc GetPage:pnum];
    if (!page || ![page IsValid]) {
        return;
    }

    PTMarkup *shapeMarkup = [[PTMarkup alloc] initWithAnn:shapeAnnot];
    NSString *subj = [shapeMarkup GetSubject];
    PTPDFRect *bbox = [shapeAnnot GetRect];
    // Only skip when a Bauhub decorative stamp is already near the corner — not when BauhubAreaPin is set on the shape.
    if (BauhubPageHasPinStampNearShapeCorner(page, bbox, subj)) {
        @try {
            [shapeAnnot SetCustomData:kBauhubAreaPinCustomKey value:@"1"];
        } @catch (__unused NSException *e) {
        }
        return;
    }

    NSString *imgName = @"bauhubCommentPin";
    if ([subj isEqualToString:@"Attachment"]) {
        imgName = @"bauhubAttachmentPin";
    } else if ([subj isEqualToString:@"Task"]) {
        imgName = BauhubWebTaskPinImageName();
    }
    UIImage *rawImage = BauhubLoadTemplateImageNamed(imgName);
    if (!rawImage && [subj isEqualToString:@"Task"]) {
        rawImage = BauhubLoadTemplateImageNamed(@"task_111111");
    }
    if (!rawImage) {
        NSLog(@"BauhubStampPinForAreaShape: missing pin image '%@' (check app / plugin bundle assets)", imgName);
        return;
    }
    UIImage *image = BauhubAreaPinCorrectImage(rawImage);
    if (!image) {
        return;
    }

    @try {
        double x1 = [bbox GetX1], y1 = [bbox GetY1], x2 = [bbox GetX2], y2 = [bbox GetY2];
        double minX = MIN(x1, x2);
        double maxY = MAX(y1, y2);

        PTPDFRect *stampRect = [[PTPDFRect alloc] initWithX1:0 y1:0 x2:image.size.width y2:image.size.height];
        // Decorative area-pin size in page points. With the e_ptno_zoom flag the rect drives the
        // constant on-screen size; smaller than the legacy 25 pt cap, which rendered too large.
        double maxWidth = 18.0;
        double maxHeight = 18.0;

        PTRotate ctrlRotation = [pdfViewCtrl GetRotation];
        PTRotate pageRotation = [page GetRotation];
        PTRotate viewRotation = ((pageRotation + ctrlRotation) % 4);

        if ([page GetPageWidth:(e_ptcrop)] < maxWidth) {
            maxWidth = [page GetPageWidth:(e_ptcrop)];
        }
        if ([page GetPageHeight:(e_ptcrop)] < maxHeight) {
            maxHeight = [page GetPageHeight:(e_ptcrop)];
        }

        if (viewRotation == e_pt90 || viewRotation == e_pt270) {
            maxWidth = maxWidth + maxHeight;
            maxHeight = maxWidth - maxHeight;
            maxWidth = maxWidth - maxHeight;
        }

        CGFloat scaleFactor = MIN(maxWidth / [stampRect Width], maxHeight / [stampRect Height]);
        CGFloat stampWidth = [stampRect Width] * scaleFactor;
        CGFloat stampHeight = [stampRect Height] * scaleFactor;

        if (ctrlRotation == e_pt90 || ctrlRotation == e_pt270) {
            stampWidth = stampWidth + stampHeight;
            stampHeight = stampWidth - stampHeight;
            stampWidth = stampWidth - stampHeight;
        }

        PTStamper *stamper = [[PTStamper alloc] initWithSize_type:e_ptabsolute_size a:stampWidth b:stampHeight];
        [stamper SetAlignment:e_pthorizontal_left vertical_alignment:e_ptvertical_bottom];
        [stamper SetAsAnnotation:YES];

        /* Same as point pins: anchor is stamp center in page space, then default matrix, then -w/2 -h/2 */
        double anchorX = minX + 4.0 + stampWidth / 2.0;
        double anchorY = maxY - 4.0 - stampHeight / 2.0;
        PTMatrix2D *mtx = [page GetDefaultMatrix:NO box_type:e_ptcrop angle:0];
        PTPDFPoint *pagePt = [[PTPDFPoint alloc] initWithPx:anchorX py:anchorY];
        pagePt = [mtx Mult:pagePt];

        CGFloat xPos = [pagePt getX] - (stampWidth / 2.0);
        CGFloat yPos = [pagePt getY] - (stampHeight / 2.0);

        double pageWidth = [page GetPageWidth:(e_ptcrop)];
        if (xPos > pageWidth - stampWidth) {
            xPos = pageWidth - stampWidth;
        }
        if (xPos < 0) {
            xPos = 0;
        }
        double pageHeight = [page GetPageHeight:(e_ptcrop)];
        if (yPos > pageHeight - stampHeight) {
            yPos = pageHeight - stampHeight;
        }
        if (yPos < 0) {
            yPos = 0;
        }

        [stamper SetPosition:xPos vertical_distance:yPos use_percentage:NO];

        PTPageSet *pageSet = [[PTPageSet alloc] initWithOne_page:pnum];
        NSData *data = UIImagePNGRepresentation(image);
        PTObjSet *hintSet = [[PTObjSet alloc] init];
        PTObj *encoderHints = [hintSet CreateArray];
        [encoderHints PushBackName:@"Flate"];
        [encoderHints PushBackName:@"Level"];
        [encoderHints PushBackNumber:9.0];
        PTImage *stampImage = [PTImage CreateWithDataSimple:[doc GetSDFDoc] buf:data buf_size:data.length encoder_hints:encoderHints];

        PTRotate stampRotation = (4 - ctrlRotation) % 4;
        [stamper SetRotation:stampRotation * 90.0];
        [stamper StampImage:doc src_img:stampImage dest_pages:pageSet];

        int numAnnots = [page GetNumAnnots];
        if (numAnnots < 1) {
            return;
        }
        PTAnnot *stampAnnot = [page GetAnnot:numAnnots - 1];
        PTObj *obj = [stampAnnot GetSDFObj];
        [obj PutString:PTImageStampAnnotationIdentifier value:@""];
        [obj PutNumber:PTImageStampAnnotationRotationDegreeIdentifier value:0.0];

        PTMarkup *markupAnnot = [[PTMarkup alloc] initWithAnn:stampAnnot];
        if ([markupAnnot IsValid] && subj.length > 0) {
            [markupAnnot SetSubject:subj];
            @try {
                [markupAnnot SetContents:@""];
            } @catch (__unused NSException *e) {
            }
        }
        @try {
            [stampAnnot SetCustomData:kBauhubDecorativeAreaPinKey value:@"1"];
            @try {
                PTObj *shapeUidObj = [shapeAnnot GetUniqueID];
                if ([shapeUidObj IsValid] && [shapeUidObj IsString]) {
                    NSString *uid = [shapeUidObj GetAsPDFText];
                    if (uid.length > 0) {
                        [stampAnnot SetCustomData:kBauhubParentShapeUidKey value:uid];
                    }
                }
            } @catch (__unused NSException *e) {
            }
            PTPDFRect *cr = [stampAnnot GetRect];
            double ax = MIN([cr GetX1], [cr GetX2]);
            double ay = MAX([cr GetY1], [cr GetY2]);
            [stampAnnot SetCustomData:kBauhubPinPageAx value:[NSString stringWithFormat:@"%.8f", ax]];
            [stampAnnot SetCustomData:kBauhubPinPageAy value:[NSString stringWithFormat:@"%.8f", ay]];
            [stampAnnot SetFlag:e_ptlocked value:YES];
        } @catch (__unused NSException *e) {
        }
        // Match WebViewer XFDF: flags="print,nozoom,norotate" + local-timezone dates on the stamp.
        BauhubApplyWebStyleStampFlagsAndDates(stampAnnot);
        [stampAnnot RefreshAppearance];

        [shapeAnnot SetCustomData:kBauhubAreaPinCustomKey value:@"1"];
        // Do NOT call applyBauhubMarkupStyle here: BauhubDecorateAllImportedAreaPins also uses this path and must
        // keep each shape's embedded fill/stroke from the PDF (same as web — import does not recolor).

        [pdfViewCtrl UpdateWithAnnot:stampAnnot page_num:pnum];
        [pdfViewCtrl UpdateWithAnnot:shapeAnnot page_num:pnum];
        BauhubScheduleDecorativeAreaPinZoomSync(pdfViewCtrl);
    } @catch (NSException *exception) {
        NSLog(@"BauhubStampPinForAreaShape: %@", exception.reason);
    }
}

/// Stamp after the rectangle tool finishes its create transaction; avoids StampImage failing silently under tool DocLock.
static void BauhubScheduleAreaPinStamp(PTPDFViewCtrl *pdfViewCtrl, int pageHint, PTAnnot *shapeAnnot) {
    if (!pdfViewCtrl || !shapeAnnot) {
        return;
    }
    __weak PTPDFViewCtrl *weakPvc = pdfViewCtrl;
    __weak PTAnnot *weakAnn = shapeAnnot;
    int hint = pageHint;
    dispatch_async(dispatch_get_main_queue(), ^{
        PTPDFViewCtrl *pvc = weakPvc;
        PTAnnot *ann = weakAnn;
        if (!pvc || !ann || ![ann IsValid]) {
            return;
        }
        NSError *err = nil;
        [pvc DocLock:YES withBlock:^(PTPDFDoc *doc) {
            int pnum = BauhubFindPageNumberForAnnotInDoc(doc, ann);
            if (pnum < 1) {
                pnum = hint;
            }
            if (pnum < 1) {
                pnum = (int)pvc.currentPage;
            }
            if (pnum < 1) {
                return;
            }
            BauhubStampPinForAreaShape(pvc, doc, pnum, ann);
        } error:&err];
        if (err) {
            NSLog(@"BauhubScheduleAreaPinStamp: %@", err);
        }
    });
}

static void BauhubDecorateAllImportedAreaPins(PTPDFViewCtrl *pdfViewCtrl, PTPDFDoc *doc) {
    if (!pdfViewCtrl || !doc) {
        return;
    }
    int pageCount = [doc GetPageCount];
    for (int p = 1; p <= pageCount; p++) {
        PTPage *page = [doc GetPage:p];
        int n = [page GetNumAnnots];
        NSMutableArray<PTAnnot *> *targets = [NSMutableArray array];
        for (int i = 0; i < n; i++) {
            PTAnnot *a = [page GetAnnot:i];
            if (!BauhubAnnotShouldReceiveAreaPin(a)) {
                continue;
            }
            // Do not skip based on BauhubAreaPin custom data alone: XFDF/server flows can keep the flag on
            // the square while the decorative stamp annot never persisted. Stamping uses geometry + decorative key.
            [targets addObject:a];
        }
        for (PTAnnot *shape in targets) {
            BauhubStampPinForAreaShape(pdfViewCtrl, doc, p, shape);
        }
    }
    [pdfViewCtrl Update:YES];
    BauhubScheduleDecorativeAreaPinZoomSync(pdfViewCtrl);
}

/**
 * No-op: decorative area-pin stamps carry the real `e_ptno_zoom` flag (set in
 * `BauhubApplyWebStyleStampFlagsAndDates`), so PDFTron keeps them at a constant on-screen size
 * natively — exactly like the web viewer (XFDF `flags="print,nozoom,norotate"`).
 *
 * This previously *faked* no-zoom by resizing each pin's page-space rect on every zoom change. With
 * the flag now in place that manual resize fought the flag: zooming in shrank the page-rect, and
 * because the flag ties on-screen size to the rect, the pin visibly shrank. The `kBauhubPinPageAx/Ay`
 * keys are still used as the pin's fixed corner anchor.
 */
static void BauhubScheduleDecorativeAreaPinZoomSync(PTPDFViewCtrl *pdfViewCtrl) {
    (void)pdfViewCtrl;
}

#pragma mark - BauhubRectangleMarkupTool

static NSUInteger sBauhubAreaFillArgb = 0xFF2368E5;
static NSUInteger sBauhubAreaStrokeArgb = 0xFF2368E5;
/// Matches bauhub-fe PdfTronTools.ts `this.StrokeThickness || 1` in applyPinIconDraw.
static const double kBauhubAreaStrokeWidth = 1.0;
/// Matches web `annotation.Opacity = 0.3` for the **fill**; stroke stays opaque in the custom appearance stream.
static const CGFloat kBauhubAreaMarkupOpacity = 0.3f;

static void BauhubZeroSquarePolygonBorderForCustomAppearance(PTAnnot *annot);
static void BauhubConfigureAreaMarkupDrawingContext(CGContextRef ctx);

static NSUInteger BauhubNormalizeArgb(NSUInteger c) {
    return 0xFF000000 | (c & 0xFFFFFF);
}

static PTColorPt *BauhubColorPtFromOpaqueArgb(NSUInteger argb) {
    argb = BauhubNormalizeArgb(argb);
    double r = ((argb >> 16) & 0xFF) / 255.0;
    double g = ((argb >> 8) & 0xFF) / 255.0;
    double b = (argb & 0xFF) / 255.0;
    return [[PTColorPt alloc] initWithX:r y:g z:b w:0.0];
}

static NSUInteger BauhubRgbArgbFromColorPt(PTColorPt *c) {
    if (!c) {
        return sBauhubAreaFillArgb;
    }
    int r = (int)round([c Get:0] * 255.0);
    int g = (int)round([c Get:1] * 255.0);
    int b = (int)round([c Get:2] * 255.0);
    r = MAX(0, MIN(255, r));
    g = MAX(0, MIN(255, g));
    b = MAX(0, MIN(255, b));
    return 0xFF000000u | ((NSUInteger)r << 16) | ((NSUInteger)g << 8) | (NSUInteger)b;
}

// (Removed) BauhubFillBlendedTowardWhite — previously used as the fallback IC value when the
// custom translucent AP couldn't be built. Writing a white-blended pastel into IC corrupted
// cross-platform colour parity (web/iOS apply opacity="0.3" on top of IC, so a pre-blended IC
// became visibly washed-out on every save). Fallback paths now keep IC = opaque + lower CA to
// 0.3, matching the Android implementation. The Android sister-side keeps a `fillArgbBlendedTowardWhite`
// helper purely to *recover* the original opaque colour from older Android saves that wrote the
// blended IC; iOS never had that problem in the success path so no recovery helper is needed here.

static BOOL BauhubPolyLineAppendClosedPath(PTElementBuilder *builder, PTPolyLine *pline) {
    if (!builder || !pline || ![pline IsValid]) {
        return NO;
    }
    int vc = (int)[pline GetVertexCount];
    if (vc < 3) {
        return NO;
    }
    [builder PathBegin];
    PTPDFPoint *p0 = [pline GetVertex:0];
    [builder MoveTo:[p0 getX] y:[p0 getY]];
    for (int i = 1; i < vc; i++) {
        PTPDFPoint *pi = [pline GetVertex:i];
        [builder LineTo:[pi getX] y:[pi getY]];
    }
    [builder ClosePath];
    return YES;
}

/// Standard `RefreshAppearance` draws an **opaque** interior. Web uses canvas alpha on the fill only; mirror with `ca` / `CA` in the AP stream.
static BOOL BauhubSetTranslucentAreaMarkupAppearance(
    PTAnnot *annot,
    PTPDFDoc *doc,
    PTColorPt *fill,
    PTColorPt *stroke,
    double fillOpacity,
    double lineWidth,
    double minSquareSide) {
    if (!annot || !doc || !fill || !stroke || ![annot IsValid]) {
        return NO;
    }
    if (fillOpacity < 0.0 || fillOpacity > 1.0) {
        return NO;
    }
    PTAnnotType t = [annot GetType];
    double sqLX = 0, sqLY = 0, sqW = 0, sqH = 0;
    PTPolyLine *polygonLine = nil;
    if (t == e_ptSquare) {
        PTPDFRect *r = [annot GetRect];
        double ax1 = [r GetX1], ay1 = [r GetY1], ax2 = [r GetX2], ay2 = [r GetY2];
        sqLX = MIN(ax1, ax2);
        sqLY = MIN(ay1, ay2);
        sqW = fabs(ax2 - ax1);
        sqH = fabs(ay2 - ay1);
        if (sqW < minSquareSide || sqH < minSquareSide) {
            return NO;
        }
    } else if (t == e_ptPolygon) {
        polygonLine = [[PTPolyLine alloc] initWithAnn:annot];
        if (![polygonLine IsValid] || [polygonLine GetVertexCount] < 3) {
            return NO;
        }
    } else {
        return NO;
    }

    PTColorSpace *rgb = [PTColorSpace CreateDeviceRGB];
    if (!rgb) {
        return NO;
    }
    PTElementWriter *writer = [[PTElementWriter alloc] init];
    PTElementBuilder *builder = [[PTElementBuilder alloc] init];
    @try {
        [writer WriterBeginWithSDFDoc:[doc GetSDFDoc] compress:YES];

        if (t == e_ptSquare) {
            if (fillOpacity > 0.0) {
                PTElement *fillEl = [builder CreateRect:sqLX y:sqLY width:sqW height:sqH];
                PTGState *gsf = [fillEl GetGState];
                [gsf SetFillColorSpace:rgb];
                [gsf SetFillColorWithColorPt:fill];
                [gsf SetFillOpacity:fillOpacity];
                [gsf SetStrokeOpacity:1.0];
                [fillEl SetPathFill:YES];
                [fillEl SetPathStroke:NO];
                [writer WritePlacedElement:fillEl];
            }

            PTElement *strokeEl = [builder CreateRect:sqLX y:sqLY width:sqW height:sqH];
            PTGState *gss = [strokeEl GetGState];
            [gss SetStrokeColorSpace:rgb];
            [gss SetStrokeColorWithColorPt:stroke];
            [gss SetStrokeOpacity:1.0];
            [gss SetFillOpacity:1.0];
            [gss SetLineWidth:lineWidth];
            [strokeEl SetPathFill:NO];
            [strokeEl SetPathStroke:YES];
            [writer WritePlacedElement:strokeEl];
        } else {
            if (fillOpacity > 0.0) {
                if (!BauhubPolyLineAppendClosedPath(builder, polygonLine)) {
                    return NO;
                }
                PTElement *fillPath = [builder PathEnd];
                PTGState *gsf = [fillPath GetGState];
                [gsf SetFillColorSpace:rgb];
                [gsf SetFillColorWithColorPt:fill];
                [gsf SetFillOpacity:fillOpacity];
                [gsf SetStrokeOpacity:1.0];
                [fillPath SetPathFill:YES];
                [fillPath SetPathStroke:NO];
                [writer WritePlacedElement:fillPath];
            }

            if (!BauhubPolyLineAppendClosedPath(builder, polygonLine)) {
                return NO;
            }
            PTElement *strokePath = [builder PathEnd];
            PTGState *gss = [strokePath GetGState];
            [gss SetStrokeColorSpace:rgb];
            [gss SetStrokeColorWithColorPt:stroke];
            [gss SetStrokeOpacity:1.0];
            [gss SetFillOpacity:1.0];
            [gss SetLineWidth:lineWidth];
            [strokePath SetPathFill:NO];
            [strokePath SetPathStroke:YES];
            [writer WritePlacedElement:strokePath];
        }

        PTObj *form = [writer End];
        if (![form IsValid]) {
            return NO;
        }
        PTPDFRect *bb = [annot GetRect];
        double bx1 = MIN([bb GetX1], [bb GetX2]);
        double by1 = MIN([bb GetY1], [bb GetY2]);
        double bx2 = MAX([bb GetX1], [bb GetX2]);
        double by2 = MAX([bb GetY1], [bb GetY2]);
        [form PutRect:@"BBox" x1:bx1 y1:by1 x2:bx2 y2:by2];

        [annot SetAppearance:form annot_state:e_ptnormal app_state:0];
        return YES;
    } @catch (__unused NSException *e) {
        return NO;
    }
}

/// Per-annot version: rebuilds the translucent Bauhub AP for a single area markup. No-op for
/// non-Bauhub annotations. Caller must hold a write lock on the document.
static void BauhubReapplyTranslucentAreaMarkupAppearanceForAnnotImpl(PTAnnot *a, PTPDFDoc *doc) {
    if (!a || !doc || !BauhubAnnotShouldReceiveAreaPin(a)) {
        return;
    }
    PTMarkup *m = [[PTMarkup alloc] initWithAnn:a];
    if (![m IsValid]) {
        return;
    }
    int icn = 0;
    @try {
        icn = [m GetInteriorColorCompNum];
    } @catch (__unused NSException *e) {
        icn = 0;
    }
    PTColorPt *fillPt = nil;
    if (icn >= 3) {
        @try {
            fillPt = [m GetInteriorColor];
        } @catch (__unused NSException *e) {
            fillPt = nil;
        }
    }
    if (fillPt == nil) {
        fillPt = BauhubColorPtFromOpaqueArgb(sBauhubAreaFillArgb);
    }
    PTColorPt *strokePt = nil;
    int ccn = 0;
    @try {
        ccn = [a GetColorCompNum];
    } @catch (__unused NSException *e) {
        ccn = 0;
    }
    if (ccn >= 3) {
        @try {
            strokePt = [a GetColor];
        } @catch (__unused NSException *e) {
            strokePt = nil;
        }
    }
    if (strokePt == nil) {
        strokePt = BauhubColorPtFromOpaqueArgb(sBauhubAreaStrokeArgb);
    }
    double lw = kBauhubAreaStrokeWidth;
    @try {
        PTBorderStyle *bs = [a GetBorderStyle];
        if (bs != nil && [bs GetWidth] > 0.1) {
            lw = [bs GetWidth];
        }
    } @catch (__unused NSException *e) {
    }
    @try {
        [m SetOpacity:1.0];
    } @catch (__unused NSException *e) {
    }
    BOOL ok = BauhubSetTranslucentAreaMarkupAppearance(
        a, doc, fillPt, strokePt, (double)kBauhubAreaMarkupOpacity, lw, 0.5);
    if (ok) {
        BauhubZeroSquarePolygonBorderForCustomAppearance(a);
    } else {
        // Fallback (no custom AP): keep IC at the OPAQUE design colour so the exported XFDF
        // matches web/iOS expectations across platforms (web/iOS apply opacity="0.3" themselves
        // and read IC at face value). Lower CA to 0.3 so the default Square/Polygon render also
        // looks translucent. Writing a white-blended IC here used to corrupt the cross-platform
        // colour — every Android edit + iOS fallback would push the saved fill one step lighter.
        NSUInteger fillArgb = BauhubRgbArgbFromColorPt(fillPt);
        @try {
            [m SetInteriorColor:BauhubColorPtFromOpaqueArgb(fillArgb) CompNum:3];
            [m SetOpacity:(double)kBauhubAreaMarkupOpacity];
            [a RefreshAppearance];
        } @catch (__unused NSException *e) {
        }
    }
}

void PTBauhubReapplyTranslucentAreaMarkupAppearanceForAnnot(PTAnnot *annot, PTPDFDoc *doc) {
    BauhubReapplyTranslucentAreaMarkupAppearanceForAnnotImpl(annot, doc);
}

BOOL PTBauhubAnnotIsAreaMarkup(PTAnnot *annot) {
    return BauhubAnnotShouldReceiveAreaPin(annot);
}

/// After XFDF merge / `refreshAnnotAppearances`, default AP is opaque — rebuild translucent Bauhub fill + thin stroke.
static void BauhubRestoreTranslucentAreaMarkupAppearancesInDoc(PTPDFDoc *doc) {
    if (!doc) {
        return;
    }
    int pageCount = (int)[doc GetPageCount];
    for (int p = 1; p <= pageCount; p++) {
        PTPage *page = [doc GetPage:p];
        int n = (int)[page GetNumAnnots];
        for (int i = 0; i < n; i++) {
            BauhubReapplyTranslucentAreaMarkupAppearanceForAnnotImpl([page GetAnnot:i], doc);
        }
    }
}

void BauhubSetAreaMarkupPresetColors(unsigned fillArgb, unsigned strokeArgb) {
    sBauhubAreaFillArgb = BauhubNormalizeArgb(fillArgb);
    sBauhubAreaStrokeArgb = BauhubNormalizeArgb(strokeArgb);
}

/// PDFNet draws the default square border on top of a custom `ca` stream unless border width is 0 (matches Android).
static void BauhubZeroSquarePolygonBorderForCustomAppearance(PTAnnot *annot) {
    if (!annot || ![annot IsValid]) {
        return;
    }
    PTAnnotType t = [annot GetType];
    if (t != e_ptSquare && t != e_ptPolygon) {
        return;
    }
    @try {
        PTBorderStyle *bs = [annot GetBorderStyle];
        if (bs != nil) {
            [bs SetWidth:0.0];
            [annot SetBorderStyle:bs oldStyleOnly:NO];
        }
    } @catch (__unused NSException *e) {
    }
}

/// `PTCreateToolBase` rubber-band uses `setupContext:` — simple black outline + transparent interior while dragging.
static void BauhubConfigureAreaMarkupDrawingContext(CGContextRef ctx) {
    if (!ctx) {
        return;
    }
    CGContextSetRGBStrokeColor(ctx, 0.0f, 0.0f, 0.0f, 1.0f);
    CGContextSetRGBFillColor(ctx, 1.0f, 1.0f, 1.0f, 0.0f);
    CGContextSetLineWidth(ctx, (CGFloat)kBauhubAreaStrokeWidth);
}

/// While dragging, native square preview often ignores fill alpha and looks solid — black stroke + transparent fill.
static void BauhubApplyAreaToolDrawPreviewDefaults(PTPDFViewCtrl *pdfViewCtrl) {
    if (!pdfViewCtrl) {
        return;
    }
    PTRotate cpm = [pdfViewCtrl GetColorPostProcessMode];
    UIColor *strokeUI = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
    UIColor *fillUI = [UIColor colorWithWhite:1.0f alpha:0.0f];

    [PTColorDefaults setDefaultColor:strokeUI forAnnotType:e_ptSquare attribute:ATTRIBUTE_STROKE_COLOR colorPostProcessMode:cpm];
    [PTColorDefaults setDefaultColor:fillUI forAnnotType:e_ptSquare attribute:ATTRIBUTE_FILL_COLOR colorPostProcessMode:cpm];
    [PTColorDefaults setDefaultColor:strokeUI forAnnotType:e_ptPolygon attribute:ATTRIBUTE_STROKE_COLOR colorPostProcessMode:cpm];
    [PTColorDefaults setDefaultColor:fillUI forAnnotType:e_ptPolygon attribute:ATTRIBUTE_FILL_COLOR colorPostProcessMode:cpm];
}

static void BauhubScheduleReapplyBauhubAreaMarkupStyle(PTPDFViewCtrl *pdfViewCtrl, PTAnnot *annot, int pageNumber, NSString *subject) {
    if (!pdfViewCtrl || !annot || ![annot IsValid]) {
        return;
    }
    NSString *subj = (subject.length > 0) ? subject : @"Comment";
    __weak PTPDFViewCtrl *weakPvc = pdfViewCtrl;
    __weak PTAnnot *weakAnnot = annot;
    void (^reapply)(void) = ^{
        PTPDFViewCtrl *pvc = weakPvc;
        PTAnnot *a = weakAnnot;
        if (!pvc || !a || ![a IsValid]) {
            return;
        }
        NSError *err = nil;
        [pvc DocLock:YES withBlock:^(PTPDFDoc *d) {
            [BauhubRectangleMarkupTool applyBauhubMarkupStyle:a doc:d subject:subj];
        } error:&err];
        [pvc UpdateWithAnnot:a page_num:pageNumber];
    };
    dispatch_async(dispatch_get_main_queue(), reapply);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)), dispatch_get_main_queue(), reapply);
}

@implementation BauhubRectangleMarkupTool

- (double)setupContext:(CGContextRef)ctx {
    (void)[super setupContext:ctx];
    BauhubConfigureAreaMarkupDrawingContext(ctx);
    return (double)kBauhubAreaStrokeWidth;
}

- (PTAnnot *)createAnnotationWithDoc:(PTPDFDoc *)doc myRect:(PTPDFRect *)myRect
{
    PTAnnot *annot = [super createAnnotationWithDoc:doc myRect:myRect];
    [BauhubRectangleMarkupTool applyBauhubMarkupStyle:annot doc:doc subject:self.bauhubSubject];
    BauhubScheduleAreaPinStamp(self.pdfViewCtrl, (int)self.pageNumber, annot);
    BauhubScheduleReapplyBauhubAreaMarkupStyle(self.pdfViewCtrl, annot, (int)self.pageNumber, self.bauhubSubject);
    return annot;
}

+ (void)applyBauhubMarkupStyle:(PTAnnot *)annot doc:(PTPDFDoc *)doc subject:(NSString *)subject
{
    if (![annot IsValid]) {
        return;
    }
    PTMarkup *markup = [[PTMarkup alloc] initWithAnn:annot];
    if (![markup IsValid]) {
        return;
    }
    NSString *existingUid = [annot GetUniqueIDAsString];
    if (existingUid == nil || existingUid.length == 0) {
        NSString *newId = [NSUUID UUID].UUIDString;
        int bytes = (int)[newId lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        @try {
            [annot SetUniqueID:newId id_buf_sz:bytes];
        } @catch (__unused NSException *e) {
        }
    }
    NSString *subj = (subject.length > 0) ? subject : @"Comment";
    [markup SetSubject:subj];
    PTColorPt *fill = BauhubColorPtFromOpaqueArgb(sBauhubAreaFillArgb);
    PTColorPt *stroke = BauhubColorPtFromOpaqueArgb(sBauhubAreaStrokeArgb);
    [markup SetInteriorColor:fill CompNum:3];
    [annot SetColor:stroke numcomp:3];
    [markup SetOpacity:1.0];
    @try {
        PTBorderStyle *bs = [annot GetBorderStyle];
        if (bs == nil) {
            bs = [[PTBorderStyle alloc] initWithS:(PTBdStyle)0 b_width:kBauhubAreaStrokeWidth b_hr:0.0 b_vr:0.0];
        } else {
            [bs SetWidth:kBauhubAreaStrokeWidth];
        }
        [annot SetBorderStyle:bs oldStyleOnly:NO];
    } @catch (__unused NSException *e) {
    }

    BOOL usedCustomAppearance = (doc != nil)
        && BauhubSetTranslucentAreaMarkupAppearance(
            annot, doc, fill, stroke, (double)kBauhubAreaMarkupOpacity, kBauhubAreaStrokeWidth, 0.5);
    if (usedCustomAppearance) {
        BauhubZeroSquarePolygonBorderForCustomAppearance(annot);
    } else {
        // Fallback: keep IC at the OPAQUE brand colour (web/iOS read IC at face value and apply
        // opacity="0.3" themselves). Lower CA to 0.3 so the default Square/Polygon render also
        // looks translucent on iOS. A previous version wrote a white-blended IC here, which
        // shipped the lighter pastel into the saved XFDF and broke cross-platform colour parity.
        [markup SetInteriorColor:fill CompNum:3];
        @try {
            [markup SetOpacity:(double)kBauhubAreaMarkupOpacity];
            [annot RefreshAppearance];
        } @catch (__unused NSException *e) {
        }
    }

    // Match WebViewer XFDF date format (local timezone offset) on the area shape itself. Flags
    // stay at PDFTron default (print) — web emits the same for square/polygon. Both
    // BauhubRectangleMarkupTool and BauhubPolygonMarkupTool route through this method, so the
    // hook covers Comment / Attachment / Task squares + polygons in one place.
    BauhubApplyWebStyleShapeDates(annot);
}

@end

#pragma mark - BauhubPolygonMarkupTool

/**
 * Bauhub-internal extension declaring the private touch-buffer surface of {@link PTPolylineCreate}.
 *
 * Apryse's `Tools.framework` keeps in-progress polygon geometry across **two** parallel ivar arrays:
 *
 *   - {@code _touchPoints}     — screen-space taps. Drives {@code drawRect:} / rubber-band rendering.
 *                                The public {@code vertices} property is a getter alias for this.
 *   - {@code _pageTouchPoints} — page-space taps. **{@code -commitAnnotation} reads from this one**
 *                                to build the saved polygon vertices.
 *
 * {@code addTouchPoint:} / {@code removeLastTouchPoint} mutate BOTH arrays in lockstep, but the
 * public {@code -setVertices:} (and any direct manipulation of {@code _touchPoints}) only touches
 * the screen-side array. An older Bauhub undo fallback used {@code setVertices: subarray} to drop
 * a vertex — visibly the rubber-band shrank, but {@code commitAnnotation} still replayed the
 * un-done point because the page-side buffer was never trimmed.
 *
 * Selectors below are present in `Tools.framework` (verified against
 * {@code _OBJC_$_INSTANCE_METHODS_PTPolylineCreate} in the binary symbol table) but are omitted
 * from the public headers.
 */
@interface PTPolylineCreate (BauhubPolygonTouchEditing)
- (void)removeLastTouchPoint;
- (nullable NSArray<NSValue *> *)touchPoints;
- (nullable NSArray<NSValue *> *)pageTouchPoints;
@end

/// Invokes `-addTouchPoint:` whether the ABI uses `CGPoint` or an `NSValue *` wrapper (SDK-build dependent).
static void BauhubPolylineInvokeAddTouchPoint(PTPolylineCreate *poly, NSValue *screenPointValue)
{
    if (poly == nil || screenPointValue == nil) {
        return;
    }
    SEL sel = @selector(addTouchPoint:);
    if (![poly respondsToSelector:sel]) {
        return;
    }
    NSMethodSignature *sig = [poly methodSignatureForSelector:sel];
    if (sig == nil || sig.numberOfArguments < 3) {
        return;
    }
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setSelector:sel];
    const char *enc = [sig getArgumentTypeAtIndex:2];
    if (strcmp(enc, "@") == 0) {
        NSValue *__unsafe_unretained boxed = screenPointValue;
        [inv setArgument:&boxed atIndex:2];
    } else if (enc[0] == '{') {
        CGPoint p = [screenPointValue CGPointValue];
        [inv setArgument:&p atIndex:2];
    } else {
        return;
    }
    [inv invokeWithTarget:poly];
}

static void BauhubPolylineInvokeRemoveLastTouchPoint(PTPolylineCreate *poly)
{
    if (poly == nil || ![poly respondsToSelector:@selector(removeLastTouchPoint)]) {
        return;
    }
    void (*imp)(id, SEL) = (void (*)(id, SEL))[poly methodForSelector:@selector(removeLastTouchPoint)];
    imp(poly, @selector(removeLastTouchPoint));
}

/// Committed-tap count — backs the **Valmis ≥3 gate** and the dedupe baseline. Reads
/// {@code _touchPoints} (screen space; same array {@code -vertices} aliases). After a clean tap
/// cycle this matches {@code _pageTouchPoints.count} which is what {@code -commitAnnotation} consumes.
/// Mirrors Android's {@code mPagePoints.size()} — no live cursor / preview entry.
static NSUInteger BauhubPolylineCommittedPointCount(PTPolylineCreate *poly)
{
    if (poly == nil) {
        return 0;
    }
    @try {
        NSArray<NSValue *> *t = [poly touchPoints];
        if (t != nil) {
            return t.count;
        }
    } @catch (__unused NSException *e) {
    }
    return poly.vertices.count;
}

/// Largest of any internal touch buffer — used by dedupe / cancel / undo guards as a "is there
/// anything still hanging around?" probe. Picks the max so a stuck {@code _pageTouchPoints} can't
/// hide an inflated screen-side array (or vice versa) from the trim loop.
static NSUInteger BauhubPolylineEffectivePointCount(PTPolylineCreate *poly)
{
    if (poly == nil) {
        return 0;
    }
    NSUInteger v = poly.vertices.count;
    NSUInteger t = 0;
    NSUInteger p = 0;
    @try { t = [[poly touchPoints] count]; } @catch (__unused NSException *e) {}
    @try { p = [[poly pageTouchPoints] count]; } @catch (__unused NSException *e) {}
    return MAX(MAX(v, t), p);
}

/// Trim BOTH the screen-space {@code _touchPoints} and the page-space {@code _pageTouchPoints}
/// buffers down to {@code target} entries. {@code -commitAnnotation} reads {@code _pageTouchPoints}
/// exclusively, so any path that mutates only the screen array (or only {@code -vertices}) leaves
/// commit replaying the pre-mutation polygon — the exact bug behind "Valmis re-creates undone points".
///
/// Uses {@code -mutableArrayValueForKey:} so KVO observers (toolbar emit + the SDK's own rubber-band
/// invalidation) fire as the arrays shrink. Wrapped in {@code @try} per array — older Tools.framework
/// builds may not expose one of the keys via KVC.
static void BauhubPolylineTrimTouchPointsTo(PTPolylineCreate *poly, NSUInteger target)
{
    if (poly == nil) {
        return;
    }
    @try {
        NSMutableArray *t = [poly mutableArrayValueForKey:@"touchPoints"];
        while (t.count > target) {
            [t removeLastObject];
        }
    } @catch (__unused NSException *e) {
    }
    @try {
        NSMutableArray *p = [poly mutableArrayValueForKey:@"pageTouchPoints"];
        while (p.count > target) {
            [p removeLastObject];
        }
    } @catch (__unused NSException *e) {
    }
}

/// Append {@code screenPoint} to BOTH internal touch buffers — used as a redo fallback when
/// {@code -addTouchPoint:} did not grow the arrays (rare; some SDK builds short-circuit on
/// rapid programmatic calls). Converts screen → page via the live PVC so {@code -commitAnnotation}
/// later sees the restored vertex in the correct page-space coordinates.
static void BauhubPolylinePushTouchPoint(PTPolylineCreate *poly, NSValue *screenPoint, PTPDFViewCtrl *pvc)
{
    if (poly == nil || screenPoint == nil) {
        return;
    }
    @try {
        NSMutableArray *t = [poly mutableArrayValueForKey:@"touchPoints"];
        [t addObject:screenPoint];
    } @catch (__unused NSException *e) {
    }
    if (pvc == nil) {
        return;
    }
    @try {
        if (![pvc respondsToSelector:@selector(ConvScreenPtToPagePt:page_num:)]) {
            return;
        }
        CGPoint scr = [screenPoint CGPointValue];
        PTPDFPoint *scrPt = [[PTPDFPoint alloc] initWithPx:scr.x py:scr.y];
        PTPDFPoint *pgPt = [pvc ConvScreenPtToPagePt:scrPt page_num:(int)poly.pageNumber];
        if (pgPt == nil) {
            return;
        }
        NSValue *pageValue = [NSValue valueWithCGPoint:CGPointMake([pgPt getX], [pgPt getY])];
        NSMutableArray *p = [poly mutableArrayValueForKey:@"pageTouchPoints"];
        [p addObject:pageValue];
    } @catch (__unused NSException *e) {
    }
}

/**
 * Screen-space NSValue for {@code addTouchPoint:} — push onto {@code bauhubRedoStack} before
 * {@code removeLastTouchPoint}. Prefer PDFNet's {@code touchPoints} tail; otherwise convert the
 * last {@code vertices} entry from page → screen via {@code ConvPagePtToScreenPt:page_num:}.
 */
static NSValue *BauhubPolylineRedoScreenPointForUndo(PTPolylineCreate *poly, PTPDFViewCtrl *pvc)
{
    if (poly == nil) {
        return nil;
    }
    @try {
        id tp = [poly valueForKey:@"touchPoints"];
        if ([tp respondsToSelector:@selector(count)] && [tp count] > 0) {
            id last = [tp lastObject];
            if ([last isKindOfClass:[NSValue class]]) {
                return (NSValue *)last;
            }
        }
    } @catch (__unused NSException *e) {
    }
    NSArray<NSValue *> *verts = poly.vertices;
    NSValue *lastV = verts.lastObject;
    if (lastV == nil || pvc == nil) {
        return nil;
    }
    CGPoint pageCg = [lastV CGPointValue];
    PTPDFPoint *ppt = [[PTPDFPoint alloc] initWithPx:pageCg.x py:pageCg.y];
    if (![pvc respondsToSelector:@selector(ConvPagePtToScreenPt:page_num:)]) {
        return nil;
    }
    PTPDFPoint *scr = [pvc ConvPagePtToScreenPt:ppt page_num:(int)poly.pageNumber];
    if (scr == nil) {
        return nil;
    }
    return [NSValue valueWithCGPoint:CGPointMake([scr getX], [scr getY])];
}

/// Best-effort abandon of PDFNet's in-progress shape **before** switching tools (Android calls
/// AdvancedShapeCreate.clear()). iOS has no single stable public API — probe common compound-create
/// selectors so toolManager.changeTool does not finalize a partial polygon onto the page.
static void BauhubPolygonInvokeSdkAbortCreationIfAvailable(BauhubPolygonMarkupTool *tool)
{
    if (tool == nil) {
        return;
    }
    NSArray<NSString *> *names = @[
        @"cancelInteractive",
        @"cancelAnnotationCreation",
        @"cancelCreation",
        @"cancel",
        @"clear",
        @"reset",
    ];
    for (NSString *name in names) {
        SEL sel = NSSelectorFromString(name);
        if ([(id)tool respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [(id)tool performSelector:sel];
#pragma clang diagnostic pop
            return;
        }
    }
}

// Static singletons backing the Bauhub polygon-state broadcast channel.
static FlutterEventSink gBauhubPolygonStateEventSink = nil;
static __weak BauhubPolygonMarkupTool *gBauhubPolygonActiveTool = nil;
/** Fallback when {@code toolManager.tool} is not our subclass (gesture/tool swap edge cases). Cleared in {@code -dealloc}. */
static BauhubPolygonMarkupTool *gBauhubPolygonStrongActiveTool = nil;

@interface BauhubPolygonMarkupTool ()
+ (BauhubPolygonMarkupTool *)bauhub_resolveActiveTool:(nullable PTToolManager *)toolManager;
/**
 * Effective polyline point count sampled in {@code onTouchesBegan} **after** {@code super} — stable
 * baseline for the finger-down cycle. Per-gesture dedupe trims duplicate PDFNet vertices using this
 * baseline plus one as the cap (see {@code bauhubFlushVertexDedupe}).
 */
@property (nonatomic, assign) NSUInteger bauhubTapCycleBaseline;
/**
 * Bauhub-managed redo stack. PTPolylineCreate / PTPolygonCreate don't track "undone" vertices
 * the way Android's AdvancedShapeCreate does; we keep our own LIFO stack so the Flutter toolbar
 * can expose Redo while the polygon is still in-progress. Cleared whenever the user adds a new
 * vertex via a tap (pdfViewCtrl:handleTap:) — matching PDFTron's undo semantics.
 */
@property (nonatomic, strong) NSMutableArray<NSValue *> *bauhubRedoStack;
/** Whether KVO observation on {@code vertices} has been attached. */
@property (nonatomic, assign) BOOL bauhubObservingVertices;
@end

@implementation BauhubPolygonMarkupTool

- (instancetype)initWithPDFViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl
{
    self = [super initWithPDFViewCtrl:pdfViewCtrl];
    if (self) {
        _bauhubRedoStack = [NSMutableArray array];
        gBauhubPolygonStrongActiveTool = self;
        gBauhubPolygonActiveTool = self;
        [self addObserver:self forKeyPath:@"vertices" options:0 context:NULL];
        _bauhubObservingVertices = YES;
        // Push an "active, 0 vertices" snapshot so Dart knows the tool is live and can keep
        // the Point/Area pill visible until the first tap.
        dispatch_async(dispatch_get_main_queue(), ^{
            [BauhubPolygonMarkupTool emitStateSnapshotFromTool:self];
        });
    }
    return self;
}

- (void)dealloc
{
    if (_bauhubObservingVertices) {
        @try {
            [self removeObserver:self forKeyPath:@"vertices"];
        } @catch (NSException * __unused _) {
            // Observer may already have been removed; ignore.
        }
        _bauhubObservingVertices = NO;
    }
    if (gBauhubPolygonStrongActiveTool == self) {
        gBauhubPolygonStrongActiveTool = nil;
    }
    if (gBauhubPolygonActiveTool == self) {
        gBauhubPolygonActiveTool = nil;
        // Tool torn down — collapse the active-polygon toolbar.
        [BauhubPolygonMarkupTool emitDetachedStateSnapshot];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (object == self && [keyPath isEqualToString:@"vertices"]) {
        [BauhubPolygonMarkupTool emitStateSnapshotFromTool:self];
    }
}

// PDFNet often delivers the same tap via `onTouchesEnded:` and `handleTap:` — two vertex inserts.
// We trim to at most one net vertex per finger-down cycle (baseline captured in `onTouchesBegan`).
// Runs **synchronously after each callback** so both handlers run in order **without**
// `performSelector:afterDelay:0`, which queued flushes that `cancelPreviousPerformRequests` could drop
// across consecutive taps — repro: second vertex sometimes disappeared or a stale flush ran late.

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    BOOL handled = [super pdfViewCtrl:pdfViewCtrl onTouchesBegan:touches withEvent:event];
    // Baseline against committed taps — vertices.count is N+1 (live cursor) and would let dedupe
    // accept an extra vertex per tap. touchPoints.count == Android mPagePoints.size().
    self.bauhubTapCycleBaseline = BauhubPolylineCommittedPointCount((PTPolylineCreate *)self);
    return handled;
}

- (void)bauhubFlushVertexDedupe
{
    NSUInteger baseline = self.bauhubTapCycleBaseline;
    NSUInteger cap = baseline + 1;
    NSUInteger safety = 0;
    while (BauhubPolylineCommittedPointCount((PTPolylineCreate *)self) > cap && safety < 32) {
        BauhubPolylineInvokeRemoveLastTouchPoint((PTPolylineCreate *)self);
        safety++;
    }
    // `removeLastTouchPoint` should shrink BOTH `_touchPoints` and `_pageTouchPoints`, but a few
    // Tools.framework builds skip the page-side trim when called from inside the touch handler —
    // commit then replays the duplicate. Hard-trim both ivars so the gate / commit / rendering all
    // agree at the end of the tap cycle.
    BauhubPolylineTrimTouchPointsTo((PTPolylineCreate *)self, cap);
    NSUInteger finalCount = BauhubPolylineCommittedPointCount((PTPolylineCreate *)self);
    if (finalCount > baseline) {
        [self.bauhubRedoStack removeAllObjects];
    }
    [BauhubPolygonMarkupTool emitStateSnapshotFromTool:self];
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onTouchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    BOOL handled = [super pdfViewCtrl:pdfViewCtrl onTouchesEnded:touches withEvent:event];
    [self bauhubFlushVertexDedupe];
    return handled;
}

- (BOOL)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl handleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    BOOL handled = [super pdfViewCtrl:pdfViewCtrl handleTap:gestureRecognizer];
    [self bauhubFlushVertexDedupe];
    return handled;
}

- (double)setupContext:(CGContextRef)ctx {
    (void)[super setupContext:ctx];
    BauhubConfigureAreaMarkupDrawingContext(ctx);
    return (double)kBauhubAreaStrokeWidth;
}

/**
 * Unlike {@code PTRectangleCreate}, {@code PTPolygonCreate.commitAnnotation} builds the annotation
 * and sets its vertices AFTER calling {@code createAnnotationWithDoc:myRect:}. At creation-time the
 * PTPolyLine has 0 vertices, so {@code BauhubSetTranslucentAreaMarkupAppearance} (which requires ≥3)
 * silently fails and the SDK's subsequent {@code RefreshAppearance} wipes any partial style. Only
 * the subject + stroke/fill attrs written on the SDF object survive here; the custom appearance
 * stream and the decorative pin stamp must be applied after vertices exist.
 */
- (PTAnnot *)createAnnotationWithDoc:(PTPDFDoc *)doc myRect:(PTPDFRect *)myRect
{
    PTAnnot *annot = [super createAnnotationWithDoc:doc myRect:myRect];
    [BauhubRectangleMarkupTool applyBauhubMarkupStyle:annot doc:doc subject:self.bauhubSubject];
    return annot;
}

/**
 * {@code annotationAdded:onPageNumber:} is invoked by {@code PTPolylineCreate.commitAnnotation}
 * AFTER vertices have been written to the PTPolygon and the annotation is on the page — whether
 * commit comes from Bauhub's "Valmis" FAB or from PDFTron's native edit toolbar's Complete button.
 * This is where we (re)apply the translucent fill + stroke appearance stream, schedule the
 * decorative pin stamp, and schedule the deferred style reapply. Matches Android's
 * {@code BauhubPolygonMarkupTool.createMarkup} hook which also runs post-vertex.
 *
 * Style is applied BEFORE {@code super} so the {@code subject="Comment"/"Attachment"} attr is
 * visible on {@code GetSDFObj} when Flutter's annotationChanged listener exports XFDF to
 * distinguish Bauhub polygons from stock {@code PTPolygonCreate} output (pendingPin guard).
 */
- (void)annotationAdded:(PTAnnot *)annotation onPageNumber:(unsigned long)pageNumber
{
    PTPDFViewCtrl *pvc = self.pdfViewCtrl;
    if (annotation != nil && [annotation IsValid] && pvc != nil) {
        NSError *err = nil;
        [pvc DocLock:YES withBlock:^(PTPDFDoc *doc) {
            [BauhubRectangleMarkupTool applyBauhubMarkupStyle:annotation doc:doc subject:self.bauhubSubject];
        } error:&err];
        BauhubScheduleAreaPinStamp(pvc, (int)pageNumber, annotation);
        BauhubScheduleReapplyBauhubAreaMarkupStyle(pvc, annotation, (int)pageNumber, self.bauhubSubject);
    }
    // Commit clears the vertex buffer; collapse the polygon-active bar in the Flutter UI.
    [BauhubPolygonMarkupTool emitDetachedStateSnapshot];
    [super annotationAdded:annotation onPageNumber:pageNumber];
}

#pragma mark - Bauhub polygon state broadcast

+ (void)setStateEventSink:(nullable FlutterEventSink)sink
{
    gBauhubPolygonStateEventSink = sink;
}

+ (void)bauhub_polygonRunOnMainSync:(void (NS_NOESCAPE ^)(void))block
{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

/// The live polygon tool — `toolManager.tool` is authoritative when it is still our subclass.
/// `gBauhubPolygonStrongActiveTool` survives cases where `toolManager.tool` temporarily does not match
/// (weak `gBauhubPolygonActiveTool` could also be nil while the tool view is still live).
+ (BauhubPolygonMarkupTool *)bauhub_resolveActiveTool:(nullable PTToolManager *)toolManager
{
    if (toolManager != nil) {
        PTTool *currentTool = toolManager.tool;
        if ([currentTool isKindOfClass:[BauhubPolygonMarkupTool class]]) {
            return (BauhubPolygonMarkupTool *)currentTool;
        }
    }
    BauhubPolygonMarkupTool *strong = gBauhubPolygonStrongActiveTool;
    if (strong != nil && (toolManager == nil || strong.toolManager == toolManager)) {
        return strong;
    }
    return gBauhubPolygonActiveTool;
}

+ (BOOL)cancelActiveShapeWithToolManager:(nullable PTToolManager *)toolManager
{
    __block BOOL ok = NO;
    [self bauhub_polygonRunOnMainSync:^{
        BauhubPolygonMarkupTool *active = [self bauhub_resolveActiveTool:toolManager];
        if (!active) {
            return;
        }
        BauhubPolygonInvokeSdkAbortCreationIfAvailable(active);
        [active.bauhubRedoStack removeAllObjects];
        // Drain BOTH internal touch buffers via `removeLastTouchPoint` first (keeps SDK-internal
        // state machine consistent), then hard-zero them via the KVC mutable proxies. Setting
        // `vertices = @[]` alone left `_pageTouchPoints` populated and a stale tool swap could
        // commit the partial polygon onto the page on the next gesture cycle.
        NSUInteger safety = 0;
        while (BauhubPolylineEffectivePointCount((PTPolylineCreate *)active) > 0 && safety < 512) {
            BauhubPolylineInvokeRemoveLastTouchPoint((PTPolylineCreate *)active);
            safety++;
        }
        BauhubPolylineTrimTouchPointsTo((PTPolylineCreate *)active, 0);
        [BauhubPolygonMarkupTool refreshInProgressShapeOnTool:active];
        PTToolManager *tm = toolManager ?: active.toolManager;
        if (tm) {
            [tm changeTool:[PTPanTool class]];
        }
        [BauhubPolygonMarkupTool emitDetachedStateSnapshot];
        ok = YES;
    }];
    return ok;
}

+ (BOOL)cancelActiveShape
{
    return [self cancelActiveShapeWithToolManager:nil];
}

+ (BOOL)undoActiveShapePointWithToolManager:(nullable PTToolManager *)toolManager
{
    __block BOOL ok = NO;
    [self bauhub_polygonRunOnMainSync:^{
        BauhubPolygonMarkupTool *active = [self bauhub_resolveActiveTool:toolManager];
        if (!active) {
            return;
        }
        NSUInteger countBefore = BauhubPolylineCommittedPointCount((PTPolylineCreate *)active);
        if (countBefore == 0) {
            return;
        }
        NSValue *redoPoint = BauhubPolylineRedoScreenPointForUndo((PTPolylineCreate *)active, active.pdfViewCtrl);
        if (redoPoint == nil) {
            return;
        }
        [active.bauhubRedoStack addObject:redoPoint];
        BauhubPolylineInvokeRemoveLastTouchPoint((PTPolylineCreate *)active);
        // Hard-trim BOTH `_touchPoints` and `_pageTouchPoints` to the new target size so commit
        // can't replay an un-done vertex. Old code only set `vertices` (== screen-side), leaving
        // the page-side committed buffer stale → "Valmis recreates undone points" bug.
        BauhubPolylineTrimTouchPointsTo((PTPolylineCreate *)active, countBefore - 1);
        [BauhubPolygonMarkupTool refreshInProgressShapeOnTool:active];
        ok = YES;
    }];
    return ok;
}

+ (BOOL)undoActiveShapePoint
{
    return [self undoActiveShapePointWithToolManager:nil];
}

+ (BOOL)redoActiveShapePointWithToolManager:(nullable PTToolManager *)toolManager
{
    __block BOOL ok = NO;
    [self bauhub_polygonRunOnMainSync:^{
        BauhubPolygonMarkupTool *active = [self bauhub_resolveActiveTool:toolManager];
        if (!active || active.bauhubRedoStack.count == 0) {
            return;
        }
        NSValue *restored = active.bauhubRedoStack.lastObject;
        [active.bauhubRedoStack removeLastObject];
        NSUInteger countBefore = BauhubPolylineCommittedPointCount((PTPolylineCreate *)active);
        BauhubPolylineInvokeAddTouchPoint((PTPolylineCreate *)active, restored);
        // SDK's `-addTouchPoint:` should grow BOTH `_touchPoints` and `_pageTouchPoints`. If the
        // count didn't move, push to both buffers manually — otherwise commit would skip the
        // restored vertex and the rubber-band would visually lag behind the redo stack.
        NSUInteger countAfter = BauhubPolylineCommittedPointCount((PTPolylineCreate *)active);
        if (countAfter <= countBefore) {
            BauhubPolylinePushTouchPoint((PTPolylineCreate *)active, restored, active.pdfViewCtrl);
        }
        [BauhubPolygonMarkupTool refreshInProgressShapeOnTool:active fullPDFUpdate:NO];
        ok = YES;
    }];
    return ok;
}

+ (BOOL)redoActiveShapePoint
{
    return [self redoActiveShapePointWithToolManager:nil];
}

/**
 * Forces the rubber-band rendering to redraw after a programmatic mutation of {@code vertices}
 * and broadcasts a fresh state snapshot to Dart.
 *
 * Why this is needed: PTPolylineCreate's in-progress polygon is rendered by the tool view's
 * own {@code -drawRect:}, plus an overlay maintained by the parent {@code PTPDFViewCtrl}. When
 * the user taps to add a vertex, PDFTron internally calls {@code setNeedsDisplay} on both, but
 * a third-party setter assign (the path Bauhub takes for undo/redo) doesn't trip those refresh
 * hooks — the data changes but the canvas keeps showing the previous polyline. Explicitly
 * marking both the tool and the underlying PDF view as dirty puts the next runloop pass in
 * charge of redrawing them.
 *
 * KVO on {@code vertices} can also be unreliable here (the SDK occasionally bypasses the
 * property setter), so programmatic undo/redo emits explicitly after refresh.
 */
+ (void)refreshInProgressShapeOnTool:(BauhubPolygonMarkupTool *)tool
{
    [self refreshInProgressShapeOnTool:tool fullPDFUpdate:NO];
}

+ (void)refreshInProgressShapeOnTool:(BauhubPolygonMarkupTool *)tool fullPDFUpdate:(BOOL)fullPDFUpdate
{
    if (tool == nil) return;
    [tool setNeedsDisplay];
    PTPDFViewCtrl *pvc = tool.pdfViewCtrl;
    if (pvc != nil) {
        [pvc setNeedsDisplay];
        // Full `Update:YES` caused visible flicker on redo; `setNeedsDisplay` + `Update:NO` matches
        // undo and is enough once touch buffers and vertices are consistent.
        [pvc Update:fullPDFUpdate];
    }
    [BauhubPolygonMarkupTool emitStateSnapshotFromTool:tool];
}

+ (void)emitStateSnapshotFromTool:(BauhubPolygonMarkupTool *)tool
{
    FlutterEventSink sink = gBauhubPolygonStateEventSink;
    if (sink == nil || tool == nil) return;
    // Toolbar gates Valmis on `vertexCount >= 3` — must match Android's `mPagePoints.size()`.
    // PTPolylineCreate's `vertices` array carries an extra trailing live-cursor entry that
    // would push the count to N+1 after N taps and unlock Valmis at 2 taps.
    NSUInteger vertexCount = BauhubPolylineCommittedPointCount((PTPolylineCreate *)tool);
    // Use explicit @YES/@NO instead of @(boolExpression). The C expression `count > 0`
    // evaluates to int, and `@(int)` boxes as `NSNumber numberWithInt:` — Flutter's standard
    // codec then delivers it to Dart as `int` (0 / 1), and `map['canUndo'] == true` evaluates
    // to false (Dart: 1 == true is false). Forcing __NSCFBoolean ensures Dart sees a bool.
    NSDictionary *payload = @{
        @"active": @YES,
        @"vertexCount": @(vertexCount),
        @"canUndo": (vertexCount > 0) ? @YES : @NO,
        @"canRedo": (tool.bauhubRedoStack.count > 0) ? @YES : @NO,
    };
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            sink(payload);
        } @catch (NSException * __unused _) {
            // Sink can be torn down between the dispatch and delivery; tolerate it silently.
        }
    });
}

+ (void)emitDetachedStateSnapshot
{
    FlutterEventSink sink = gBauhubPolygonStateEventSink;
    if (sink == nil) return;
    NSDictionary *payload = @{
        @"active": @NO,
        @"vertexCount": @0,
        @"canUndo": @NO,
        @"canRedo": @NO,
    };
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            sink(payload);
        } @catch (NSException * __unused _) {
        }
    });
}

@end
