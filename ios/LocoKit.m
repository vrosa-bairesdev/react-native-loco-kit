// LocoKit.m

#import "LocoKit.h"


@interface RCT_EXTERN_MODULE(LocoKitModule, NSObject)

RCT_EXTERN_METHOD(setup:(NSString *) key callback:(RCTResponseSenderBlock) callback)

RCT_EXTERN_METHOD(start)

RCT_EXPORT_METHOD(isAvailable:(RCTResponseSenderBlock)callback)
{
  callback(@[@YES]);
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

@end
