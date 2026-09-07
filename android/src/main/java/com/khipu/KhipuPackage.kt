package com.khipu

import com.facebook.react.TurboReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.turbomodule.core.interfaces.TurboModule

/**
 * Extends TurboReactPackage rather than BaseReactPackage because
 * BaseReactPackage does not exist in React Native 0.73, our support floor.
 * From 0.74 on it is an empty deprecated subclass of the newer base class,
 * so behaviour is identical across the supported range.
 *
 * This is version coupling, not architecture coupling: this file lives in the
 * `main` source set and is compiled under both architectures.
 */
@Suppress("DEPRECATION")
class KhipuPackage : TurboReactPackage() {
  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
    return if (name == KhipuModuleImpl.NAME) KhipuModule(reactContext) else null
  }

  override fun getReactModuleInfoProvider() = ReactModuleInfoProvider {
    mapOf(
      KhipuModuleImpl.NAME to ReactModuleInfo(
        // Positional on purpose: ReactModuleInfo's parameter names changed
        // between RN versions (_name in 0.75.5, name in 0.87.1) while arity,
        // order and types did not. Naming them pins us to one version.
        KhipuModuleImpl.NAME,   // name
        KhipuModuleImpl.NAME,   // className
        false,                  // canOverrideExistingModule
        false,                  // needsEagerInit
        false,                  // isCxxModule
        // Derived from the class actually compiled, so it tells the truth under
        // both architectures. `ReactModuleInfo.classIsTurboModule` would be the
        // idiomatic helper but does not exist in 0.73.
        TurboModule::class.java.isAssignableFrom(KhipuModule::class.java)
      )
    )
  }
}
