// Este header es Obj-C++ a proposito: el header que emite codegen incluye
// <optional> y <vector>, y NativeKhipuSpec hereda de RCTTurboModule, que es C++.
//
// El guard no es decorativo. CocoaPods mete todos los headers del pod en su
// umbrella header, y Swift compila esa umbrella como Obj-C puro
// (-import-underlying-module esta en OTHER_SWIFT_FLAGS del pod). Sin el guard,
// el build muere antes de mirar una linea de Swift con:
//
//   error 'utility' file not found
//   error could not build module 'ReactCodegen'
//   error could not build module 'react_native_khipu'
//
// Quien lo importa de verdad es ios/Khipu.mm, que si es Obj-C++.
#ifdef __cplusplus

#import <KhipuSpec/KhipuSpec.h>

@interface Khipu : NSObject <NativeKhipuSpec>

@end

#endif
