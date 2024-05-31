#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(Khipu, NSObject)

RCT_EXTERN_METHOD(startOperation:(NSDictionary*)options
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

@end
