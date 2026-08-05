

#import <Foundation/Foundation.h>
#import <CoreMedia/CMFormatDescription.h>

@interface RTCVideoUtilT : NSObject

+ (CMVideoDimensions)outputVideoDimens:(CMVideoDimensions)inputDimens
                                  crop:(float)ratio;

+ (CMVideoDimensions)calculateDiemnsDividedByTwo:(int)width andHeight:(int)height;

+ (CMVideoDimensions)outputVideoDimensEnhanced:(CMVideoDimensions)inputDimens crop:(float)ratio;

@end
