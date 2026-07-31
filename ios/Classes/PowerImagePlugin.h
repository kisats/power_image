#import <Flutter/Flutter.h>

@interface PowerImagePlugin : NSObject<FlutterPlugin, FlutterStreamHandler>
+ (instancetype)sharedInstance;
- (void)sendImageStateEvent:(NSMutableDictionary *)event success:(BOOL)success;
- (void)sendImageProgressEvent:(NSMutableDictionary *)event;
@end
