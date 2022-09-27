//
//  Copyright © 2018-2022 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//
#import "PspdfPlatformView.h"
#import "PspdfkitFlutterConverter.h"
#import "PspdfkitFlutterHelper.h"

@import PSPDFKit;
@import PSPDFKitUI;

@interface PspdfPlatformView () <PSPDFViewControllerDelegate>
@property int64_t platformViewId;
@property(nonatomic) FlutterMethodChannel *channel;
@property(nonatomic, weak) UIViewController *flutterViewController;
@property(nonatomic) PSPDFViewController *pdfViewController;
@property(nonatomic) PSPDFNavigationController *navigationController;
@end

@implementation PspdfPlatformView

- (nonnull UIView *)view {
    return self.navigationController.view ?: [UIView new];
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id)args
                    messenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    NSString *name = [NSString stringWithFormat:@"com.pspdfkit.widget.%lld", viewId];
    _platformViewId = viewId;
    _channel = [FlutterMethodChannel methodChannelWithName:name binaryMessenger:messenger];

    _navigationController = [PSPDFNavigationController new];
    _navigationController.view.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // View controller containment
    _flutterViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
    if (_flutterViewController == nil) {
        NSLog(@"Warning: FlutterViewController is nil. This may lead to view container containment "
              @"problems with PSPDFViewController since we no longer receive UIKit lifecycle "
              @"events.");
    }
    [_flutterViewController addChildViewController:_navigationController];
    [_navigationController didMoveToParentViewController:_flutterViewController];

    NSString *documentPath = args[@"document"];
    if (documentPath != nil && [documentPath isKindOfClass:[NSString class]] &&
        [documentPath length] > 0) {
        NSDictionary *conf = args[@"configuration"];
        NSDictionary *configurationDictionary = [PspdfkitFlutterConverter
            processConfigurationOptionsDictionaryForPrefix:conf];

        PSPDFDocument *document = [PspdfkitFlutterHelper documentFromPath:documentPath];
        document.renderAnnotationTypes = PSPDFAnnotationTypeInk|PSPDFAnnotationTypeHighlight|PSPDFAnnotationTypeStamp|PSPDFAnnotationTypeNote|PSPDFAnnotationTypeFreeText|PSPDFAnnotationTypeLine|PSPDFAnnotationTypeSquare|PSPDFAnnotationTypeCircle|PSPDFAnnotationTypePolyLine|PSPDFAnnotationTypePolygon|PSPDFAnnotationTypeStrikeOut|PSPDFAnnotationTypeSquiggly;
        [PspdfkitFlutterHelper unlockWithPasswordIfNeeded:document
                                               dictionary:configurationDictionary];

        BOOL isImageDocument = [PspdfkitFlutterHelper isImageDocument:documentPath];
        PSPDFConfiguration *configuration =
            [PspdfkitFlutterConverter configuration:configurationDictionary
                                    isImageDocument:isImageDocument];

        _pdfViewController = [[PSPDFViewController alloc] initWithDocument:document
                                                             configuration:configuration];
        _pdfViewController.appearanceModeManager.appearanceMode =
            [PspdfkitFlutterConverter appearanceMode:configurationDictionary];
        _pdfViewController.pageIndex = [PspdfkitFlutterConverter pageIndex:configurationDictionary];
        _pdfViewController.delegate = self;

        if ((id)configurationDictionary != NSNull.null) {
            NSString *key;

            key = @"leftBarButtonItems";
            if (configurationDictionary[key]) {
                [PspdfkitFlutterHelper setLeftBarButtonItems:configurationDictionary[key]
                                           forViewController:_pdfViewController];
            }
            key = @"rightBarButtonItems";
            if (configurationDictionary[key]) {
                [PspdfkitFlutterHelper setRightBarButtonItems:configurationDictionary[key]
                                            forViewController:_pdfViewController];
            }
            key = @"invertColors";
            if (configurationDictionary[key]) {
                _pdfViewController.appearanceModeManager.appearanceMode =
                    [configurationDictionary[key] boolValue] ? PSPDFAppearanceModeNight
                                                             : PSPDFAppearanceModeDefault;
            }
            key = @"toolbarTitle";
            if (configurationDictionary[key]) {
                [PspdfkitFlutterHelper setToolbarTitle:configurationDictionary[key]
                                     forViewController:_pdfViewController];
            }
            key = @"documentInfoOptions";
            if (configurationDictionary[key]) {
              [PspdfkitFlutterHelper setDocumentInfoOptions:configurationDictionary[key]
                                          forViewController:_pdfViewController];
            }
            key = @"annotationSaveMode";
            if (configurationDictionary[key]) {
              NSString *value = configurationDictionary[key];
              if ([value isEqualToString:@"disabled"]) {
                _pdfViewController.document.annotationSaveMode = PSPDFAnnotationSaveModeDisabled;
              } else if ([value isEqualToString:@"externalFile"]) {
                _pdfViewController.document.annotationSaveMode = PSPDFAnnotationSaveModeExternalFile;
              } else if ([value isEqualToString:@"embedded"]) {
                _pdfViewController.document.annotationSaveMode = PSPDFAnnotationSaveModeEmbedded;
              } else if ([value isEqualToString:@"embeddedWithExternalFileAsFallback"]) {
                _pdfViewController.document.annotationSaveMode = PSPDFAnnotationSaveModeEmbeddedWithExternalFileAsFallback;
              } else {
                _pdfViewController.document.annotationSaveMode = PSPDFAnnotationSaveModeDisabled;
              }
            }
            key = @"honorDocumentPermissions";
            if (configurationDictionary[key]) {
              bool shouldHonor = [configurationDictionary[key] boolValue];
              [PSPDFKitGlobal.sharedInstance setValue:shouldHonor ? @YES:@NO forKey:PSPDFSettingKeyHonorDocumentPermissions];
              if (!shouldHonor) {
                [_pdfViewController.document.features updateFeatures];
              }
            }
            _pdfViewController.annotationToolbarController.annotationToolbar.configurations = nil;
            _pdfViewController.annotationToolbarController.annotationToolbar.editableAnnotationTypes = [NSSet setWithArray:@[
                PSPDFAnnotationStringInk,
                PSPDFAnnotationStringHighlight,
                PSPDFAnnotationStringNote,
                PSPDFAnnotationStringFreeText,
                PSPDFAnnotationStringLine,
                PSPDFAnnotationStringSquare,
                PSPDFAnnotationStringCircle,
                PSPDFAnnotationStringPolygon,
                PSPDFAnnotationStringStrikeOut,
                PSPDFAnnotationStringSquiggly
            ]];
        }
    } else {
        _pdfViewController = [[PSPDFViewController alloc] init];
    }
    [_navigationController setViewControllers:@[ _pdfViewController ] animated:NO];

    self = [super init];

    __weak id weakSelf = self;
    [_channel
        setMethodCallHandler:^(FlutterMethodCall *_Nonnull call, FlutterResult _Nonnull result) {
          [weakSelf handleMethodCall:call result:result];
        }];

    return self;
}

- (void)dealloc {
    [self cleanup];
}

- (void)cleanup {
    self.pdfViewController.document = nil;
    [self.pdfViewController.view removeFromSuperview];
    [self.pdfViewController removeFromParentViewController];
    [self.navigationController.navigationBar removeFromSuperview];
    [self.navigationController.view removeFromSuperview];
    [self.navigationController removeFromParentViewController];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    [PspdfkitFlutterHelper processMethodCall:call
                                      result:result
                           forViewController:self.pdfViewController];
}

#pragma mark - PSPDFViewControllerDelegate

- (void)pdfViewControllerDidDismiss:(PSPDFViewController *)pdfController {
    // Don't hold on to the view controller object after dismissal.
    [self cleanup];
}

@end
