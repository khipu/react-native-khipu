package com.khipu

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule

/**
 * Module declaration for the old architecture (classic bridge), the same shape
 * 3.0.5 shipped. Logic lives in [KhipuModuleImpl].
 */
@ReactModule(name = KhipuModuleImpl.NAME)
class KhipuModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  private val impl = KhipuModuleImpl(reactContext)

  override fun getName(): String {
    return KhipuModuleImpl.NAME
  }

  @ReactMethod
  fun startOperation(operationOptions: ReadableMap, promise: Promise) {
    impl.startOperation(operationOptions, promise)
  }
}
