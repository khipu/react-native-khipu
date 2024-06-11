package com.khipu

import android.app.Activity
import android.content.Intent
import com.facebook.react.bridge.BaseActivityEventListener
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableNativeArray
import com.facebook.react.bridge.WritableNativeMap
import com.khipu.client.KHIPU_RESULT_EXTRA
import com.khipu.client.KhipuColors
import com.khipu.client.KhipuOptions
import com.khipu.client.KhipuResult
import com.khipu.client.getKhipuLauncherIntent
import kotlin.Int
import kotlin.String
import kotlin.let


class KhipuModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String {
    return NAME
  }

  private var startOperationPromise: Promise? = null

  private val activityEventListener =
    object : BaseActivityEventListener() {
      override fun onActivityResult(
        activity: Activity?,
        requestCode: Int,
        resultCode: Int,
        intent: Intent?
      ) {
        if (requestCode == START_OPERATION_REQUEST) {
          startOperationPromise?.let { promise ->
            when (resultCode) {
              Activity.RESULT_OK -> {
                val result = intent?.extras?.getSerializable(KHIPU_RESULT_EXTRA) as KhipuResult
                val returnMap = WritableNativeMap()
                returnMap.putString("operationId", result.operationId)
                returnMap.putString("result", result.result)
                returnMap.putString("exitTitle", result.exitTitle)
                returnMap.putString("exitMessage", result.exitMessage)
                returnMap.putString("exitUrl", result.exitUrl)
                returnMap.putString("failureReason", result.failureReason)
                returnMap.putString("continueUrl", result.continueUrl)

                val events = WritableNativeArray()
                for (event in result.events) {
                  val eventMap = WritableNativeMap()
                  eventMap.putString("name", event.name)
                  eventMap.putString("type", event.type)
                  eventMap.putString("timestamp", event.timestamp)
                  events.pushMap(eventMap)
                }
                returnMap.putArray("events", events)
                promise.resolve(returnMap)
              }
            }
            startOperationPromise = null
          }
        }
      }
    }

  init {
    reactContext.addActivityEventListener(activityEventListener)
  }

  @ReactMethod
  fun startOperation(operationOptions: ReadableMap, promise: Promise) {

    val activity = currentActivity

    if (activity == null) {
      promise.reject(NO_AVAILABLE_VIEW, "Activity doesn't exist")
      return
    }

    if (operationOptions.getString("operationId") == null) {
      promise.reject(NO_OPERATION_ID, "OperationId is needed to start the operation")
      return
    }

    startOperationPromise = promise


    val optionsBuilder: KhipuOptions.Builder = KhipuOptions.Builder()
    val options = operationOptions.getMap("options")

    if (options !== null) {

      options.getString("title")?.let { optionsBuilder.topBarTitle(it) }
      options.getString("titleImageUrl")?.let { optionsBuilder.topBarImageUrl(it) }
      options.getBoolean("skipExitPage").let { optionsBuilder.skipExitPage(it) }
      options.getString("locale")?.let { optionsBuilder.locale(it) }
      if (options.hasKey("theme")) {
        val theme: String = options.getString("theme")!!
        if ("light" == theme) {
          optionsBuilder.theme(KhipuOptions.Theme.LIGHT)
        } else if ("dark" == theme) {
          optionsBuilder.theme(KhipuOptions.Theme.DARK)
        } else if ("system" == theme) {
          optionsBuilder.theme(KhipuOptions.Theme.SYSTEM)
        }
      }

      val colorsBuilder: KhipuColors.Builder = KhipuColors.Builder()
      if (options.hasKey("colors")) {
        val colors = options.getMap("colors")!!
        colors.getString("lightBackground")?.let { colorsBuilder.lightBackground(it) }
        colors.getString("lightOnBackground")?.let { colorsBuilder.lightOnBackground(it) }
        colors.getString("lightPrimary")?.let { colorsBuilder.lightPrimary(it) }
        colors.getString("lightOnPrimary")?.let { colorsBuilder.lightOnPrimary(it) }
        colors.getString("lightTopBarContainer")?.let { colorsBuilder.lightTopBarContainer(it) }
        colors.getString("lightOnTopBarContainer")?.let { colorsBuilder.lightOnTopBarContainer(it) }
        colors.getString("darkBackground")?.let { colorsBuilder.darkBackground(it) }
        colors.getString("darkOnBackground")?.let { colorsBuilder.darkOnBackground(it) }
        colors.getString("darkPrimary")?.let { colorsBuilder.darkPrimary(it) }
        colors.getString("darkOnPrimary")?.let { colorsBuilder.darkOnPrimary(it) }
        colors.getString("darkTopBarContainer")?.let { colorsBuilder.darkTopBarContainer(it) }
        colors.getString("darkOnTopBarContainer")?.let { colorsBuilder.darkOnTopBarContainer(it) }
      }
      optionsBuilder.colors(colorsBuilder.build());
    }

    val intent = getKhipuLauncherIntent(
      context = activity.baseContext,
      operationId = operationOptions.getString("operationId")!!,
      options = optionsBuilder.build()
    )
    activity.startActivityForResult(intent, START_OPERATION_REQUEST)
  }

  companion object {
    const val NAME = "Khipu"
    const val START_OPERATION_REQUEST = 10010101
    const val NO_AVAILABLE_VIEW = "NO_AVAILABLE_VIEW"
    const val NO_OPERATION_ID = "NO_OPERATION_ID"
  }
}
