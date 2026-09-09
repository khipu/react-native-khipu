package com.khipu

import android.app.Activity
import android.content.Context
import com.facebook.react.bridge.ActivityEventListener
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import org.junit.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.doReturn
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.times
import org.mockito.kotlin.verify

/**
 * The promise lifecycle of [KhipuModuleImpl]: every promise handed to
 * `startOperation` must end up settled exactly once. A promise that is neither
 * resolved nor rejected leaves the merchant's `await` hanging forever.
 */
class KhipuModuleImplTest {

  private val activity = mock<Activity> {
    on { baseContext } doReturn mock<Context>()
  }

  private fun reactContext(): ReactApplicationContext = mock {
    on { currentActivity } doReturn activity
  }

  private fun options(operationId: String = "op-1"): ReadableMap = mock {
    on { getString("operationId") } doReturn operationId
    on { getMap("options") } doReturn null
  }

  private fun listenerOf(context: ReactApplicationContext): ActivityEventListener {
    val captor = argumentCaptor<ActivityEventListener>()
    verify(context).addActivityEventListener(captor.capture())
    return captor.firstValue
  }

  @Test
  fun `a cancelled operation settles the promise`() {
    val context = reactContext()
    val impl = KhipuModuleImpl(context)
    val promise = mock<Promise>()

    impl.startOperation(options(), promise)
    listenerOf(context).onActivityResult(
      activity,
      KhipuModuleImpl.START_OPERATION_REQUEST,
      Activity.RESULT_CANCELED,
      null
    )

    // Settled exactly once. What must not happen is silence.
    verify(promise, times(1)).reject(any<String>(), any<String>())
  }

  @Test
  fun `a result with no payload settles the promise instead of throwing`() {
    val context = reactContext()
    val impl = KhipuModuleImpl(context)
    val promise = mock<Promise>()

    impl.startOperation(options(), promise)
    // RESULT_OK with no extras: the unchecked cast used to throw out of the
    // listener, which settles nothing and leaves the caller waiting.
    listenerOf(context).onActivityResult(
      activity,
      KhipuModuleImpl.START_OPERATION_REQUEST,
      Activity.RESULT_OK,
      null
    )

    verify(promise, times(1)).reject(any<String>(), any<String>())
    verify(promise, never()).resolve(anyOrNull())
  }

  @Test
  fun `a second operation while one is pending is rejected instead of dropped`() {
    val context = reactContext()
    val impl = KhipuModuleImpl(context)
    val first = mock<Promise>()
    val second = mock<Promise>()

    impl.startOperation(options("op-1"), first)
    impl.startOperation(options("op-2"), second)

    verify(second, times(1)).reject(any<String>(), any<String>())
    verify(first, never()).reject(any<String>(), any<String>())
    verify(activity, times(1))
      .startActivityForResult(anyOrNull(), eq(KhipuModuleImpl.START_OPERATION_REQUEST))
  }
}
