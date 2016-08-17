#import <Cordova/CDVPlugin.h>
#import <objc/runtime.h>

@interface CameraModule : CDVPlugin  

- (void)getPicture:(CDVInvokedUrlCommand *)command;

@end

