

#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>
#import "RTCI420FrameT.h"


typedef NS_ENUM(uint8_t, VideoPackOrientation) {
    VideoPackOrientationPortrait               = 0, //No rotation
    VideoPackOrientationLandscapeLeft          = 1, //Rotate 90 degrees clockwise
    VideoPackOrientationPortraitUpsideDown     = 2, //Rotate 180 degrees
    VideoPackOrientationLandscapeRight         = 3, //Rotate 270 degrees clockwise
};

@interface RTCYUVConverterT : NSObject

+ (RTCI420FrameT *)pixelBufferToI420:(CVImageBufferRef)pixelBuffer
                           withCrop:(float)cropRatio
                         targetSize:(CGSize)size
                     andOrientation:(VideoPackOrientation)orientation;

+ (CVPixelBufferRef)i420FrameToPixelBuffer:(RTCI420FrameT *)i420Frame;

+ (CMSampleBufferRef)pixelBufferToSampleBuffer:(CVPixelBufferRef)pixelBuffer;

@end
