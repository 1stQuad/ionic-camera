/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
Application preview view.
*/

@import AVFoundation;

#import "CameraModuleView.h"

@implementation CameraModuleView

+ (Class)layerClass
{
	return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureSession *)session
{
	AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
	return previewLayer.session;
}

- (void)setSession:(AVCaptureSession *)session
{
	AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
	previewLayer.session = session;
}

//- (instancetype)initWithFrame:(CGRect)frame
//{
//    self = [super initWithFrame:frame];
//    if (self) {
//        self.camFrame = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"moneyFrame.png"]];
//        [self.camFrame setUserInteractionEnabled:NO];
//        
//        [self addSubview:self.camFrame];
//    }
//    return self;
//}

//- (void)updateConstraints
//{
//    NSLayoutConstraint *xCenterConstraint = [NSLayoutConstraint constraintWithItem:self.camFrame attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0];
//    [self addConstraint:xCenterConstraint];
//    
//    NSLayoutConstraint *yCenterConstraint = [NSLayoutConstraint constraintWithItem:self.camFrame attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0];
//    
//    [self addConstraint:yCenterConstraint];
//}
@end
