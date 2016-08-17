#import "CameraModule.h"
//#import <Cordova/CDVAvailability.h>
//#import "AAPLPreviewView.h"


@interface CameraModule()

@property (nonatomic, strong) NSString *callbackId;

@end


@implementation CameraModule

#pragma mark - Actions

- (void)getPicture:(CDVInvokedUrlCommand *)command {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"tt" message:@"nice" delegate:nil cancelButtonTitle:@"ok" otherButtonTitles: nil];
    [alert show];
    
    BOOL hasError = NO;
  
    CDVPluginResult *pluginResult;
    
    //UIView *camView = [[AAPLPreviewView alloc] initWithFrame:self.viewController.view.frame];
    //UIViewController *camController = [[UIViewController alloc] init];
    //camController.view = camView;
    //[self.viewController presentViewController:camController animated:YES completion:^{
    
    //}];
    
    if (hasError == NO) {
    _callbackId = command.callbackId;
    } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Has error"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

#pragma mark - Processing



@end

