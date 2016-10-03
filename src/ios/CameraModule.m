#import "CameraModule.h"
#import "CameraModuleView.h"
#import "UIImage+CropScaleOrientation.h"
#import <objc/message.h>

@import AVFoundation;
@import Photos;
//#import <Cordova/CDVAvailability.h>

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * SessionRunningContext = &SessionRunningContext;

typedef NS_ENUM( NSInteger, AVCamSetupResult ) {
    AVCamSetupResultSuccess,
    AVCamSetupResultCameraNotAuthorized,
    AVCamSetupResultSessionConfigurationFailed
};




@interface CameraModule()

@property (nonatomic, strong) NSString *callbackId;

// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;


@property (nonatomic, weak) IBOutlet CameraModuleView *previewView;

@property (nonatomic, getter=isSessionRunning) BOOL sessionRunning;
@property (nonatomic) AVCamSetupResult setupResult;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;

@property (nonatomic, assign) int targetWidth;
@property (nonatomic, assign) int targetHeight;

@property (nonatomic, strong) UIImageView *camFrame;
@property (nonatomic, strong) UIImageView *takedPhoto;

@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIImageView *spinnerBackView;

@property (assign) BOOL isRecognizing;
@property (assign) BOOL photoIsVisible;

@end


@implementation CameraModule

#pragma mark - Actions

- (void)getPicture:(CDVInvokedUrlCommand *)command {
    
    [self setupView];
    
    BOOL hasError = NO;
  
    CDVPluginResult *pluginResult;
    self.targetWidth = (int) [[command argumentAtIndex:0 withDefault:@(1280)] integerValue];
    self.targetHeight = (int) [[command argumentAtIndex:1 withDefault:@(1280)] integerValue];
    
    if (hasError == NO) {
        _callbackId = command.callbackId;
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Has error"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void)pictureRecognized:(id)something
{
    self.isRecognizing = false;

    [self stopSpining];
}

- (void)backPressed
{
    [self closeCam];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"cancelled"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_callbackId];
}

#pragma mark -
- (void)imageTaked:(UIImage *)img
{
    self.takedPhoto.backgroundColor = [UIColor blackColor];
    self.takedPhoto.image =  img;
    self.takedPhoto.contentMode = UIViewContentModeScaleAspectFit;
    self.photoIsVisible = YES;

    [self setupOrientatedCamFrame];
    self.isRecognizing = YES;
    [self startSpining];
}

- (void)hideTakenPhoto
{
    self.takedPhoto.backgroundColor = [UIColor clearColor];
    self.takedPhoto.image = nil;
    self.photoIsVisible = NO;
}

- (void)startSpining
{
    self.spinner.hidden = NO;
    self.spinnerBackView.hidden = NO;

    [self.spinner startAnimating];
}

- (void)stopSpining
{
    self.spinner.hidden = YES;
    self.spinnerBackView.hidden = YES;
    [self.spinner stopAnimating];
}

#pragma mark - Processing

- (void)setupView
{
    self.isRecognizing = NO;
    self.photoIsVisible = NO;
    __weak CameraModule *wself = self;
    
    UIViewController *vc = [[UIViewController alloc] init];
    
    vc.view = [[CameraModuleView alloc] initWithFrame:self.viewController.view.frame];
    self.previewView = (CameraModuleView *) vc.view;
    [vc.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(snapStillImage:)]];
    
    
    
    self.camFrame = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"moneyFrame.png"]];
    [self.camFrame setUserInteractionEnabled:NO];

    
    
    [self.viewController presentViewController:vc animated:YES completion:^{
        [vc.view addSubview:wself.camFrame];
        wself.camFrame.translatesAutoresizingMaskIntoConstraints = NO;
        
        NSLayoutConstraint *xCenterConstraint = [NSLayoutConstraint constraintWithItem:wself.camFrame attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:vc.view attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0];
        [vc.view addConstraint:xCenterConstraint];
        NSLayoutConstraint *yCenterConstraint = [NSLayoutConstraint constraintWithItem:wself.camFrame attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:vc.view attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0];
        [vc.view addConstraint:yCenterConstraint];
        
        
        //setup view for taked photo
        wself.takedPhoto = [[UIImageView alloc] init];
        wself.takedPhoto.frame = wself.viewController.view.frame;
        [wself.previewView addSubview:wself.takedPhoto];
  
        [wself setupOrientatedCamFrame];

        wself.spinnerBackView = [[UIImageView alloc] initWithFrame:CGRectMake(0,0,70,70)];
        wself.spinnerBackView.backgroundColor = [UIColor blackColor];
        wself.spinnerBackView.layer.cornerRadius = 10.0;
        wself.spinnerBackView.translatesAutoresizingMaskIntoConstraints = NO;
        wself.spinner = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        wself.spinner.frame = CGRectMake((wself.spinnerBackView.frame.size.width-wself.spinner.frame.size.width)/2,
                                         (wself.spinnerBackView.frame.size.height-wself.spinner.frame.size.height)/2,
                                         wself.spinner.frame.size.width,
                                         wself.spinner.frame.size.height);
        
        [wself.spinnerBackView addSubview:wself.spinner];
        [wself.takedPhoto addSubview:wself.spinnerBackView];
        
        NSLayoutConstraint *xSpinCenterConstraint = [NSLayoutConstraint constraintWithItem:wself.spinnerBackView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:wself.takedPhoto attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0];
        [wself.takedPhoto addConstraint:xSpinCenterConstraint];
        NSLayoutConstraint *ySpinCenterConstraint = [NSLayoutConstraint constraintWithItem:wself.spinnerBackView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:wself.takedPhoto attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0];
        [wself.takedPhoto addConstraint:ySpinCenterConstraint];
        
        NSLayoutConstraint *wSpinCenterConstraint = [NSLayoutConstraint constraintWithItem:wself.spinnerBackView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:70];
        [wself.takedPhoto addConstraint:wSpinCenterConstraint];
        NSLayoutConstraint *hSpinCenterConstraint = [NSLayoutConstraint constraintWithItem:wself.spinnerBackView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:70];
        [wself.takedPhoto addConstraint:hSpinCenterConstraint];
        
        wself.spinner.hidden = YES;
        wself.spinnerBackView.hidden = YES;
        [wself viewWillAppear:NO];
        
        
        
        //setup navigation bar
        UINavigationBar *myNav = [[UINavigationBar alloc] init];

//        UINavigationBar *myNav = [[UINavigationBar alloc]initWithFrame:CGRectMake(0, 0, 320, 55)];
        [UINavigationBar appearance].barTintColor = [UIColor blackColor];
        [wself.previewView addSubview:myNav];
        myNav.translatesAutoresizingMaskIntoConstraints = NO;
        
        
        UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"nav bar button label")
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:wself
                                                                      action:@selector(backPressed)];
        cancelItem.image = [UIImage imageNamed:@"backButtonWhiteArrow.png"];
        UINavigationItem *navigItem = [[UINavigationItem alloc] initWithTitle:@""];

        
        navigItem.leftBarButtonItem = cancelItem;
        myNav.items = [NSArray arrayWithObjects: navigItem,nil];
        cancelItem.tintColor = [UIColor whiteColor];
        
        [UIBarButtonItem appearance].tintColor = [UIColor whiteColor];
        
        CGFloat navigationBarHeight = 55.f;// + [UIApplication sharedApplication].statusBarFrame.size.height;
        [vc.view addConstraints: @[
                                     [NSLayoutConstraint constraintWithItem: vc.view
                                                                  attribute: NSLayoutAttributeLeft
                                                                  relatedBy: NSLayoutRelationEqual
                                                                     toItem: myNav
                                                                  attribute: NSLayoutAttributeLeft
                                                                 multiplier: 1.0
                                                                   constant: 0.0],
                                     [NSLayoutConstraint constraintWithItem: vc.view
                                                                  attribute: NSLayoutAttributeRight
                                                                  relatedBy: NSLayoutRelationEqual
                                                                     toItem: myNav
                                                                  attribute: NSLayoutAttributeRight
                                                                 multiplier: 1.0
                                                                   constant: 0.0],
                                     [NSLayoutConstraint constraintWithItem: vc.topLayoutGuide
                                                                  attribute: NSLayoutAttributeTop
                                                                  relatedBy: NSLayoutRelationEqual
                                                                     toItem: myNav
                                                                  attribute: NSLayoutAttributeTop
                                                                 multiplier: 1.0
                                                                   constant: 0.0],
                                     [NSLayoutConstraint constraintWithItem: myNav
                                                                  attribute: NSLayoutAttributeHeight
                                                                  relatedBy: NSLayoutRelationEqual
                                                                     toItem: nil
                                                                  attribute: NSLayoutAttributeNotAnAttribute
                                                                 multiplier: 1.0
                                                                   constant: navigationBarHeight],
                                     ]];
        

    }];
    
    
    
    // Create the AVCaptureSession.
    self.session = [[AVCaptureSession alloc] init];
    
    // Setup the preview view.
    self.previewView.session = self.session;
    
    // Communicate with the session and other session objects on this queue.
    self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL );
    
    //    self.setupResult = AVCamSetupResultSuccess;
    
    switch ( [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] )
    {
        case AVAuthorizationStatusAuthorized:
        {
            // The user has previously granted access to the camera.
            break;
        }
        case AVAuthorizationStatusNotDetermined:
        {
            // The user has not yet been presented with the option to grant video access.
            // We suspend the session queue to delay session setup until the access request has completed to avoid
            // asking the user for audio access if video access is denied.
            // Note that audio access will be implicitly requested when we create an AVCaptureDeviceInput for audio during session setup.
            dispatch_suspend( self.sessionQueue );
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^( BOOL granted ) {
                if ( ! granted ) {
                    wself.setupResult = AVCamSetupResultCameraNotAuthorized;
                }
                dispatch_resume( wself.sessionQueue );
            }];
            break;
        }
        default:
        {
            // The user has previously denied access.
            self.setupResult = AVCamSetupResultCameraNotAuthorized;
            break;
        }
    }
    
    // Setup the capture session.
    // In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, or connections from multiple threads at the same time.
    // Why not do all of this on the main queue?
    // Because -[AVCaptureSession startRunning] is a blocking call which can take a long time. We dispatch session setup to the sessionQueue
    // so that the main queue isn't blocked, which keeps the UI responsive.
    dispatch_async( self.sessionQueue, ^{
        if ( wself.setupResult != AVCamSetupResultSuccess ) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:NSLocalizedString(@"Camera is not available", "error message")];
            [wself.commandDelegate sendPluginResult:pluginResult callbackId:wself.callbackId];
//            [self closeCam];
            return;
        }
        
        wself.backgroundRecordingID = UIBackgroundTaskInvalid;
        NSError *error = nil;
        
        AVCaptureDevice *videoDevice = [CameraModule deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        
        if ( ! videoDeviceInput ) {
            NSLog( @"Could not create video device input: %@", error );
        }
        
        [wself.session beginConfiguration];
        
        if ( [wself.session canAddInput:videoDeviceInput] ) {
            [wself.session addInput:videoDeviceInput];
            wself.videoDeviceInput = videoDeviceInput;
            
            dispatch_async( dispatch_get_main_queue(), ^{
                // Why are we dispatching this to the main queue?
                // Because AVCaptureVideoPreviewLayer is the backing layer for AAPLPreviewView and UIView
                // can only be manipulated on the main thread.
                // Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
                // on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                
                // Use the status bar orientation as the initial video orientation. Subsequent orientation changes are handled by
                // -[viewWillTransitionToSize:withTransitionCoordinator:].
                UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
                AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
                if ( statusBarOrientation != UIInterfaceOrientationUnknown ) {
                    initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
                }
                
                AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)wself.previewView.layer;
                previewLayer.connection.videoOrientation = initialVideoOrientation;
            } );
        }
        else {
            NSLog( @"Could not add video device input to the session" );
            wself.setupResult = AVCamSetupResultSessionConfigurationFailed;
        }
        
        
        AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        if ( [wself.session canAddOutput:movieFileOutput] ) {
            [wself.session addOutput:movieFileOutput];
            AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            if ( connection.isVideoStabilizationSupported ) {
                connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
            }
            wself.movieFileOutput = movieFileOutput;
        }
        else {
            NSLog( @"Could not add movie file output to the session" );
            wself.setupResult = AVCamSetupResultSessionConfigurationFailed;
        }
        
        AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        if ( [wself.session canAddOutput:stillImageOutput] ) {
            stillImageOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
            [wself.session addOutput:stillImageOutput];
            wself.stillImageOutput = stillImageOutput;
        }
        else {
            NSLog( @"Could not add still image output to the session" );
            wself.setupResult = AVCamSetupResultSessionConfigurationFailed;
        }
        
        [wself.session commitConfiguration];
    } );
}


- (void)orientationChanged:(NSNotification *)notification{
    NSLog(@"rot");
    UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
    AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationLandscapeLeft;
    if ( statusBarOrientation != UIInterfaceOrientationUnknown ) {
        initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
    }
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
    previewLayer.connection.videoOrientation = initialVideoOrientation;
    [self setupOrientatedCamFrame];

}

- (UIImage *)rotateImage:(UIImage *)image onDegrees:(float)degrees
{
    CGFloat rads = M_PI * degrees / 180;
    float newSide = MAX([image size].width, [image size].height);
    CGSize size =  CGSizeMake(newSide, newSide);
    UIGraphicsBeginImageContext(size);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, newSide/2, newSide/2);
    CGContextRotateCTM(ctx, rads);
    CGContextDrawImage(UIGraphicsGetCurrentContext(),CGRectMake(-[image size].width/2,-[image size].height/2,size.width, size.height),image.CGImage);
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}

- (void)setupOrientatedCamFrame
{
    UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
    if (statusBarOrientation == AVCaptureVideoOrientationLandscapeRight || statusBarOrientation == AVCaptureVideoOrientationLandscapeLeft) {
        [self.camFrame setTransform:CGAffineTransformMakeRotation(M_PI * (90) / 180.0)];
    }
    else
    {
        [self.camFrame setTransform:CGAffineTransformMakeRotation(M_PI * (0) / 180.0)];
    }
    self.takedPhoto.frame = self.previewView.frame;

}

- (void)closeCam
{
    __weak CameraModule *wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [wself.viewController dismissViewControllerAnimated:YES completion:^{
            
        }];
        [wself viewDidDisappear:YES];
    });
}

- (void)viewWillAppear:(BOOL)animated
{
    __weak CameraModule *wself = self;
    dispatch_async( self.sessionQueue, ^{
        switch ( wself.setupResult )
        {
            case AVCamSetupResultSuccess:
            {
                // Only setup observers and start the session running if setup succeeded.
                [wself addObservers];
                [wself.session startRunning];
                wself.sessionRunning = wself.session.isRunning;
                break;
            }
            case AVCamSetupResultCameraNotAuthorized:
            {
                dispatch_async( dispatch_get_main_queue(), ^{
                    NSString *message = NSLocalizedString( @"AVCam doesn't have permission to use the camera, please change privacy settings", @"Alert message when the user has denied access to the camera" );
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    // Provide quick access to Settings.
                    UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"Settings", @"Alert button to open Settings" ) style:UIAlertActionStyleDefault handler:^( UIAlertAction *action ) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                    }];
                    [alertController addAction:settingsAction];
                    [wself.viewController presentViewController:alertController animated:YES completion:nil];
                } );
                break;
            }
            case AVCamSetupResultSessionConfigurationFailed:
            {
                dispatch_async( dispatch_get_main_queue(), ^{
                    NSString *message = NSLocalizedString( @"Unable to capture media", @"Alert message when something goes wrong during capture session configuration" );
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    [wself.viewController presentViewController:alertController animated:YES completion:nil];
                } );
                break;
            }
        }
    } );

}

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
    if ( device.hasFlash && [device isFlashModeSupported:flashMode] ) {
        NSError *error = nil;
        if ( [device lockForConfiguration:&error] ) {
            device.flashMode = flashMode;
            [device unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    }
}

- (NSURL *)urlTransformer:(NSURL*)url
{
    NSURL * urlToTransform = url;
    
    // for backwards compatibility - we check if this property is there
    SEL sel = NSSelectorFromString(@"urlTransformer");
    if ([self.commandDelegate respondsToSelector:sel]) {
        // grab the block from the commandDelegate
        NSURL* (^urlTransformer)(NSURL*) = ((id(*)(id, SEL))objc_msgSend)(self.commandDelegate, sel);
        // if block is not null, we call it
        if (urlTransformer) {
            urlToTransform = urlTransformer(url);
        }
    }
    
    return urlToTransform;
}

- (IBAction)snapStillImage:(id)sender
{
    if (self.isRecognizing) {
        return;
    }
    if (self.photoIsVisible) {
        [self hideTakenPhoto];
        return;
    }
    
    __weak CameraModule *wself = self;
    
    dispatch_async( self.sessionQueue, ^{
        wself.takedPhoto.image = nil;

        AVCaptureConnection *connection = [wself.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)wself.previewView.layer;
        
        // Update the orientation on the still image output video connection before capturing.
        connection.videoOrientation = previewLayer.connection.videoOrientation;
        
        // Flash set to Auto for Still Capture.
        [CameraModule setFlashMode:AVCaptureFlashModeAuto forDevice:self.videoDeviceInput.device];
        
        // Capture a still image.
        [wself.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^( CMSampleBufferRef imageDataSampleBuffer, NSError *error ) {
            if ( imageDataSampleBuffer ) {
                // The sample buffer is not retained. Create image data before saving the still image to the photo library asynchronously.
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                UIImage *img = [UIImage imageWithData:imageData];
                img = [img imageByScalingNotCroppingForSize:(CGSize){wself.targetWidth, wself.targetHeight}];
                imageData = UIImageJPEGRepresentation(img, 1);
                
                NSString *temporaryFileName = [NSProcessInfo processInfo].globallyUniqueString;
                NSString *temporaryFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[temporaryFileName stringByAppendingPathExtension:@"jpg"]];
                NSURL *temporaryFileURL = [NSURL fileURLWithPath:temporaryFilePath];
                [imageData writeToURL:temporaryFileURL options:NSDataWritingAtomic error:&error];
                
                CDVPluginResult *result = nil;
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[[wself urlTransformer:temporaryFileURL] absoluteString]];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [wself imageTaked:img];
                    [wself.commandDelegate sendPluginResult:result callbackId:wself.callbackId];
                });
//                [self closeCam];
            }
            else {
                NSLog( @"Could not capture still image: %@", error );
            }
        }];
    } );
}


- (void)viewDidDisappear:(BOOL)animated
{
    __weak CameraModule *wself = self;
    dispatch_async( self.sessionQueue, ^{
        if ( wself.setupResult == AVCamSetupResultSuccess ) {
            [wself.session stopRunning];
            [wself removeObservers];
        }
    } );
    
}

- (void)addObservers
{
    [self.session addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:SessionRunningContext];
    [self.stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:CapturingStillImageContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.videoDeviceInput.device];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
    // A session can only run when the app is full screen. It will be interrupted in a multi-app layout, introduced in iOS 9,
    // see also the documentation of AVCaptureSessionInterruptionReason. Add observers to handle these session interruptions
    // and show a preview is paused message. See the documentation of AVCaptureSessionWasInterruptedNotification for other
    // interruption reasons.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(orientationChanged:)    name:UIDeviceOrientationDidChangeNotification  object:nil];

}

- (void)removeObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.session removeObserver:self forKeyPath:@"running" context:SessionRunningContext];
    [self.stillImageOutput removeObserver:self forKeyPath:@"capturingStillImage" context:CapturingStillImageContext];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];

}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    __weak CameraModule *wself = self;
    if ( context == CapturingStillImageContext ) {
        BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];
        
        if ( isCapturingStillImage ) {
            dispatch_async( dispatch_get_main_queue(), ^{
                wself.previewView.layer.opacity = 0.0;
                [UIView animateWithDuration:0.25 animations:^{
                    wself.previewView.layer.opacity = 1.0;
                }];
            } );
        }
    }
    else if ( context == SessionRunningContext ) {
        BOOL isSessionRunning = [change[NSKeyValueChangeNewKey] boolValue];
        
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = devices.firstObject;
    
    for ( AVCaptureDevice *device in devices ) {
        if ( device.position == position ) {
            captureDevice = device;
            break;
        }
    }
    
    return captureDevice;
}



@end

