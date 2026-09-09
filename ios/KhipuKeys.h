// The dictionary keys that cross between ios/Khipu.mm and ios/Khipu.swift,
// declared once.
//
// Under the new architecture Khipu.mm reads a typed codegen struct and rebuilds
// an NSDictionary for Swift; under the old one JS hands Swift that dictionary
// directly. Either way both sides have to agree on the spelling, and a literal
// on each side means a rename silently yields nil instead of a build error.
// Here the compiler checks the constant name at both ends.
//
// Values must match the keys in src/NativeKhipu.ts, which is what JS sends
// under the old architecture. src/__tests__/key-contract.test.ts asserts it.

#import <Foundation/Foundation.h>

// StartOperationOptions
extern NSString * const KhipuKeyOperationId;
extern NSString * const KhipuKeyOptions;
// KhipuOptions
extern NSString * const KhipuKeyLocale;
extern NSString * const KhipuKeyTitle;
extern NSString * const KhipuKeyTitleImageUrl;
extern NSString * const KhipuKeySkipExitPage;
extern NSString * const KhipuKeySkipExitSuccessPage;
extern NSString * const KhipuKeyShowFooter;
extern NSString * const KhipuKeyShowMerchantLogo;
extern NSString * const KhipuKeyShowPaymentDetails;
extern NSString * const KhipuKeyTheme;
extern NSString * const KhipuKeyColors;
// KhipuColors
extern NSString * const KhipuKeyLightBackground;
extern NSString * const KhipuKeyLightOnBackground;
extern NSString * const KhipuKeyLightPrimary;
extern NSString * const KhipuKeyLightOnPrimary;
extern NSString * const KhipuKeyLightTopBarContainer;
extern NSString * const KhipuKeyLightOnTopBarContainer;
extern NSString * const KhipuKeyDarkBackground;
extern NSString * const KhipuKeyDarkOnBackground;
extern NSString * const KhipuKeyDarkPrimary;
extern NSString * const KhipuKeyDarkOnPrimary;
extern NSString * const KhipuKeyDarkTopBarContainer;
extern NSString * const KhipuKeyDarkOnTopBarContainer;
// KhipuResult
extern NSString * const KhipuKeyExitTitle;
extern NSString * const KhipuKeyExitMessage;
extern NSString * const KhipuKeyExitUrl;
extern NSString * const KhipuKeyResult;
extern NSString * const KhipuKeyFailureReason;
extern NSString * const KhipuKeyContinueUrl;
extern NSString * const KhipuKeyEvents;
// KhipuEvent
extern NSString * const KhipuKeyName;
extern NSString * const KhipuKeyType;
extern NSString * const KhipuKeyTimestamp;
