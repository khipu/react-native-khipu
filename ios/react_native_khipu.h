// This file exists for its NAME, not its contents.
//
// On React Native 0.75.5 the Swift-generated header ends with
// `#import <react_native_khipu/react_native_khipu.h>`, but CocoaPods names the
// umbrella after the pod (hyphens) while the module uses underscores, so the
// import does not resolve and Khipu.mm fails to compile. Shipping a header
// under the name Swift expects fixes it without changing how merchants
// integrate. Same hyphen/underscore clash that khipu_spm_fix.rb handles for
// modulemaps; see s.header_dir in the podspec.
//
// RN 0.87.1 resolves it via `@import React;` and never emits that import.
//
// It must stay empty: Khipu.swift uses no Obj-C type from this pod, and this
// header lands in the umbrella, which Swift compiles as plain Obj-C.

#import <Foundation/Foundation.h>
