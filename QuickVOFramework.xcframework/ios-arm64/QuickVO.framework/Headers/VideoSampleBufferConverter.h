

#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>
#import <WebRTC/WebRTC.h>
NS_ASSUME_NONNULL_BEGIN

@interface VideoSampleBufferConverter : NSObject

+ (void)PixelBuffer:(int )width height:(int )height data:(NSData *)data block:(void(^)(CVPixelBufferRef ))cb;
+ (void)pixelBufferWithI420Buffer:(RTCI420Buffer *)buffer block:(void(^)(CVPixelBufferRef ))cb;
@end

NS_ASSUME_NONNULL_END
