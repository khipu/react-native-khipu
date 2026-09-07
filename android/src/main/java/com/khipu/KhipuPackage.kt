package com.khipu

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider

class KhipuPackage : BaseReactPackage() {
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
        // Cannot be hardcoded to true: under the old architecture KhipuModule
        // is not a TurboModule. This helper derives it from the class actually
        // compiled and exists identically in 0.75.5 and 0.87.1.
        ReactModuleInfo.classIsTurboModule(KhipuModule::class.java)
      )
    )
  }
}
