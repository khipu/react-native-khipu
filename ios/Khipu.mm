#import "Khipu.h"

#import <memory>

#import "react_native_khipu-Swift.h"

// El struct que emite codegen es una vista de solo lectura sobre el
// NSDictionary original: lo guarda en un `_v` privado y, en React Native
// 0.87.1, NO expone `unsafeRawValue()`. Ese accesor solo lo emite el
// generador de structs de constantes (serializeConstantsStruct.js), no el de
// argumentos de metodo (serializeRegularStruct.js), asi que el diccionario se
// reconstruye desde los accesores tipados.
//
// No es ceremonia: cada `options.titleImageUrl()` ES el contrato de
// compilacion que compra esta migracion. Si una clave se renombra en
// src/NativeKhipu.ts, el accesor desaparece y este archivo deja de compilar en
// vez de fallar callado en runtime. El parseo de valores sigue viviendo en un
// solo lugar, Khipu.swift.

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
