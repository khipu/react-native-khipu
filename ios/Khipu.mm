#import "Khipu.h"

#ifdef RCT_NEW_ARCH_ENABLED

#import <memory>

#import "react_native_khipu-Swift.h"

// The codegen struct is a read-only view over the original NSDictionary and,
// in RN 0.87.1, exposes no raw accessor (`unsafeRawValue()` comes from the
// constants-struct generator, not the method-argument one), so the dictionary
// is rebuilt from the typed accessors.
//
// That is the point, not ceremony: every `options.titleImageUrl()` is the
// compile-time contract this migration buys. Rename a key in NativeKhipu.ts and
// this file stops compiling instead of failing silently at runtime. Value
// parsing still lives in one place, Khipu.swift.

static void KhipuPutString(NSMutableDictionary *target, NSString *key, NSString *_Nullable value)
{
  if (value != nil) {
    target[key] = value;
  }
}

static void KhipuPutBool(NSMutableDictionary *target, NSString *key, const std::optional<bool> &value)
{
  if (value.has_value()) {
    target[key] = @(value.value());
  }
}

static NSDictionary *KhipuColorsAsDictionary(const JS::NativeKhipu::KhipuColors &colors)
{
  NSMutableDictionary *result = [NSMutableDictionary new];
  KhipuPutString(result, @"lightBackground", colors.lightBackground());
  KhipuPutString(result, @"lightOnBackground", colors.lightOnBackground());
  KhipuPutString(result, @"lightPrimary", colors.lightPrimary());
  KhipuPutString(result, @"lightOnPrimary", colors.lightOnPrimary());
  KhipuPutString(result, @"lightTopBarContainer", colors.lightTopBarContainer());
  KhipuPutString(result, @"lightOnTopBarContainer", colors.lightOnTopBarContainer());
  KhipuPutString(result, @"darkBackground", colors.darkBackground());
  KhipuPutString(result, @"darkOnBackground", colors.darkOnBackground());
  KhipuPutString(result, @"darkPrimary", colors.darkPrimary());
  KhipuPutString(result, @"darkOnPrimary", colors.darkOnPrimary());
  KhipuPutString(result, @"darkTopBarContainer", colors.darkTopBarContainer());
  KhipuPutString(result, @"darkOnTopBarContainer", colors.darkOnTopBarContainer());
  return result;
}

static NSDictionary *KhipuOptionsAsDictionary(const JS::NativeKhipu::KhipuOptions &options)
{
  NSMutableDictionary *result = [NSMutableDictionary new];
  KhipuPutString(result, @"locale", options.locale());
  KhipuPutString(result, @"title", options.title());
  KhipuPutString(result, @"titleImageUrl", options.titleImageUrl());
  KhipuPutBool(result, @"skipExitPage", options.skipExitPage());
  KhipuPutBool(result, @"skipExitSuccessPage", options.skipExitSuccessPage());
  KhipuPutBool(result, @"showFooter", options.showFooter());
  KhipuPutBool(result, @"showMerchantLogo", options.showMerchantLogo());
  KhipuPutBool(result, @"showPaymentDetails", options.showPaymentDetails());
  KhipuPutString(result, @"theme", options.theme());

  const std::optional<JS::NativeKhipu::KhipuColors> colors = options.colors();
  if (colors.has_value()) {
    result[@"colors"] = KhipuColorsAsDictionary(colors.value());
  }

  return result;
}

@implementation Khipu {
  KhipuImpl *_impl;
}

RCT_EXPORT_MODULE()

- (instancetype)init
{
  if (self = [super init]) {
    _impl = [KhipuImpl new];
  }
  return self;
}

- (void)startOperation:(JS::NativeKhipu::StartOperationOptions &)options
               resolve:(RCTPromiseResolveBlock)resolve
                reject:(RCTPromiseRejectBlock)reject
{
  NSMutableDictionary *payload = [NSMutableDictionary new];
  KhipuPutString(payload, @"operationId", options.operationId());

  const std::optional<JS::NativeKhipu::KhipuOptions> khipuOptions = options.options();
  if (khipuOptions.has_value()) {
    payload[@"options"] = KhipuOptionsAsDictionary(khipuOptions.value());
  }

  [_impl startOperation:payload resolve:resolve reject:reject];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeKhipuSpecJSI>(params);
}

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

@end

#else // !RCT_NEW_ARCH_ENABLED

// OLD ARCHITECTURE: declare the module the way 3.0.5 did. Two measured
// blockers, not a style preference:
//
// 1. Without TurboModules there is no JSI class to register via getTurboModule.
//    RCT_EXPORT_MODULE() with no exported method leaves the module with no
//    methods at all, and merchants get a useless object.
//
// 2. The block above must import "react_native_khipu-Swift.h" to see KhipuImpl,
//    and on RN 0.75.5 that header does not compile: swiftc cannot resolve React
//    as a module there (0.75.5 does not declare React-Core with
//    :modular_headers => true), so instead of `@import React;` it falls back to
//    the pod umbrella and emits an import that does not resolve. See
//    ios/react_native_khipu.h.
//
// RCT_EXTERN_REMAP_MODULE solves both: it exports "Khipu" pointing at the Swift
// class, exports the method, and needs no Swift-generated header because the
// link to KhipuImpl is done by the linker, not the compiler.
//
// The selector must match ios/Khipu.swift exactly; renaming it there breaks
// this at runtime, not at compile time.

#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_REMAP_MODULE(Khipu, KhipuImpl, NSObject)

RCT_EXTERN_METHOD(startOperation:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

@end

#endif // RCT_NEW_ARCH_ENABLED
