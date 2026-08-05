

#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>

typedef NS_ENUM(NSUInteger, I420FramePlane) {
    I420FramePlaneY = 0,
    I420FramePlaneU = 1,
    I420FramePlaneV = 2,
};

@interface RTCI420FrameT : NSObject

@property (nonatomic, readonly) int width;
@property (nonatomic, readonly) int height;
@property (nonatomic, readonly) int i420DataLength;
@property (nonatomic, assign)   UInt64 timetag;
@property (nonatomic, readonly) UInt8 *data;

+ (instancetype)initWithData:(NSData *)data;

- (NSData *)bytes;

- (id)initWithWidth:(int)w height:(int)h;

- (UInt8 *)dataOfPlane:(I420FramePlane)plane;

- (NSUInteger)strideOfPlane:(I420FramePlane)plane;

- (CMSampleBufferRef)convertToSampleBuffer;

- (void)getBytesQueue:(void (^)(NSData *data,NSInteger index))complete;
@end
