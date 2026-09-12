// New architecture only. Under the old architecture there are no TurboModules,
// so the module is declared entirely in Khipu.mm with RCT_EXTERN_REMAP_MODULE
// and this header stays empty.
//
// The __cplusplus guard matters: CocoaPods pulls every pod header into the
// umbrella, which Swift compiles as plain Obj-C. The codegen header includes
// <optional> and <vector>, so without the guard the build fails before Swift is
// even parsed ("'utility' file not found").
//
// RCT_NEW_ARCH_ENABLED arrives via OTHER_CPLUSPLUSFLAGS, which only applies to
// C++/Obj-C++ units, so the umbrella pass sees neither macro and gets an empty
// file, which is what we want.
#ifdef RCT_NEW_ARCH_ENABLED
#ifdef __cplusplus

#import <KhipuSpec/KhipuSpec.h>

@interface Khipu : NSObject <NativeKhipuSpec>

@end

#endif
#endif
