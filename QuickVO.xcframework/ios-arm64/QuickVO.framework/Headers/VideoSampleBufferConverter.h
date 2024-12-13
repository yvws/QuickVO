

#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoSampleBufferConverter : NSObject

+ (void)PixelBuffer:(int )width height:(int )height data:(NSData *)data block:(void(^)(CVPixelBufferRef ))cb;

@end

NS_ASSUME_NONNULL_END
