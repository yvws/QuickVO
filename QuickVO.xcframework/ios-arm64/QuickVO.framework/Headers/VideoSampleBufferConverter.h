

#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>
#import <WebRTC/WebRTC.h>
#import "RTCYUVConverterT.h"
NS_ASSUME_NONNULL_BEGIN

@interface VideoSampleBufferConverter : NSObject

+ (void)PixelBuffer:(int )width height:(int )height data:(NSData *)data block:(void(^)(CVPixelBufferRef ))cb;
+ (void)pixelBufferWithI420Buffer:(RTCI420Buffer *)buffer block:(void(^)(CVPixelBufferRef ))cb;

/// Creates a BGRA CVPixelBuffer and copies row-major pixel bytes from the extension.
+ (CVPixelBufferRef _Nullable)createBGRAPixelBufferWithWidth:(int)width
                                                      height:(int)height
                                                 bytesPerRow:(int)bytesPerRow
                                                        data:(NSData *)data;

/// BGRA → I420 (libyuv) → NV12 for WebRTC capture.
+ (void)convertBGRAPixelBuffer:(CVPixelBufferRef)bgra
                   orientation:(VideoPackOrientation)orientation
                         block:(void(^)(CVPixelBufferRef _Nullable))cb;
@end

NS_ASSUME_NONNULL_END
