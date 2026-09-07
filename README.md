# react-native-khipu

Khipu for React Native

## Installation

```sh
npm install react-native-khipu
```


## Android

### Requirements

| | |
|---|---|
| React Native | 0.73 or later |
| `compileSdk` | 34 or later |
| Kotlin Gradle plugin | 2.0.21 or later |

**React Native 0.72 and earlier are not supported on Android.** Since **August 31, 2026** Google
Play requires new apps and updates to target API 36, and a 0.72 project cannot reach that target:
its Gradle tooling does not run on the versions required to get there. If you are on 0.72 you need
to upgrade React Native, with or without Khipu. On iOS, 0.72 still works — see the Xcode 26
notes below.

### 1. Add the Khipu repository

Add it to the `allprojects` section of `android/build.gradle`. While you are there, check that
`compileSdk` and the Kotlin plugin version meet the requirements above:

```groovy
buildscript {
    ext {
        buildToolsVersion = "34.0.0"
        minSdkVersion = 21
        compileSdkVersion = 34
        targetSdkVersion = 34

        // We use NDK 23 which has both M1 support and is the side-by-side NDK version from AGP.
        ndkVersion = "23.1.7779620"
    }
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:7.3.1")
        classpath("com.facebook.react:react-native-gradle-plugin")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.21")
    }
}

allprojects {
    repositories {
        maven { url 'https://dev.khipu.com/nexus/content/repositories/khenshin' }
    }
}
```

Kotlin 2.0.21 is the floor because the Android SDK (`com.khipu:khipu-client-android`) is compiled
with it and uses `org.jetbrains.kotlin.plugin.compose`, which only exists from Kotlin 2.0 onwards.
Below `compileSdk 34` the build fails at `:app:checkDebugAarMetadata`.

**On React Native 0.73, put the Kotlin version on the `classpath` line, not only in `ext`.**
That template ships `classpath("org.jetbrains.kotlin:kotlin-gradle-plugin")` with no version and
resolves it to Kotlin 1.8 on its own, so raising `kotlinVersion` in `ext` has no effect at all and
the build fails with `The binary version of its metadata is 2.0.0, expected version is 1.8.0`.
Later templates also declare it without a version, but resolve to a Kotlin new enough that you do
not need to touch it — we verified that on 0.84.

### 2. Apply the Kotlin plugin

Check that `android/app/build.gradle` applies it:

```
apply plugin: 'kotlin-android'
```

### 3. Exclude `jackson-core` from jetifier

**Required on React Native 0.73 and 0.74**, whose templates enable jetifier by default even if you
never turned it on. Add this to `android/gradle.properties`:

```
android.jetifier.ignorelist = jackson-core
```

Without it the build fails at `:app:desugarDebugFileDependencies` with `Unsupported class file
major version 63`.

### 4. Declare the banking apps

Khipu opens the user's banking app when a payment needs reinforced authorization (2FA). Android
only allows that if your app declares which packages it may open, so add a `<queries>` element as
a direct child of `<manifest>` in `android/app/src/main/AndroidManifest.xml`.

For Chile, these are the ones:

```xml
<queries>
    <package android:name="cl.bci.pass" />
    <package android:name="cl.bancochile.mi_pass2" />
    <package android:name="net.veritran.becl.prod" />
    <package android:name="cl.scotiabank.go" />
    <package android:name="cl.santander.santanderpasschile" />
    <package android:name="com.konylabs.ItauMobileBank" />
    <package android:name="cl.bancosecurity.securitypass" />
    <package android:name="cl.bice.bicepassmobile2" />
    <package android:name="cl.consorcio.tupass" />
</queries>
```

The iOS equivalent is `LSApplicationQueriesSchemes`, described below.

### Release builds

If your project uses proguard with an aggressive configuration, add these rules to
`proguard-rules.pro` so the release APK keeps what the SDK needs:

```
-keep public class com.khipu.client.**{
    public protected *;
}
-keep class com.khipu.khenshin.protocol.** { *; }
```


## iOS

### 1. Configure your Podfile

Since version 2.15.0 the iOS SDK is resolved with Swift Package Manager instead of CocoaPods,
because the CocoaPods trunk stopped accepting new versions on December 2nd, 2026. Add this at the
top of your `ios/Podfile`:

```ruby
require File.join(
  File.dirname(`node --print "require.resolve('react-native-khipu/package.json')"`),
  "ios/khipu_spm_fix.rb"
)
```

and inside your `post_install`, **after** `react_native_post_install`:

```ruby
post_install do |installer|
  react_native_post_install(installer, config[:reactNativePath])

  khipu_fix_spm_modulemaps(installer)
end
```

The order matters: `react_native_post_install` is what runs the broken rewrite this works around.

This helper works around a React Native bug (present in 0.87.1) that prevents any pod whose name
contains a hyphen from building when it consumes SPM packages. We will drop it once the fix lands
upstream.

### Xcode 26 is required

Apple has required Xcode 26 and the iOS 26 SDK for all App Store Connect uploads since **April 28,
2026**, so if you ship your app you are already on it.

**You do not need `use_frameworks!`.** Static linking, which is React Native's default, works on
Xcode 26.

> On Xcode 16 static linking fails with `duplicate symbol ... KhipuClientIOS.o`, because React
> Native's workaround for a separate Xcode 26 issue makes the pod build into the shared products
> directory and the object ends up in the archive twice. Xcode 16 can no longer be used for App
> Store uploads, but if you are on it for some other reason, add
> `use_frameworks! :linkage => :dynamic` to your `Podfile`. Both linkage modes are verified on
> both Xcode versions.

### Known React Native build issues on recent Xcode 26 releases

Some React Native versions do not build with recent Xcode 26 releases — **with or without this
plugin**. These are React Native bugs; we list them because you will hit them while integrating
Khipu and the error messages point nowhere useful. Each was verified by uninstalling
`react-native-khipu` and confirming the build fails identically.

**All the results below were measured on Xcode 26.6.** We did not test earlier Xcode 26 releases,
so treat the "no" rows as "fails on 26.6" rather than as a claim about every Xcode 26.

| React Native | Builds on Xcode 26.6 | If not, why | Workaround |
|---|---|---|---|
| 0.72 | no | Yoga, `YGValue.h` | see below |
| 0.73, 0.74, 0.75 | yes | — | — |
| **0.76.9 through 0.83.4** | no | `fmt`, `format-inl.h` | see below |
| 0.76.8 and earlier, 0.83.5 and later, 0.84, 0.85, 0.87 | yes | — | — |

We built 0.72, 0.73, 0.74.7, 0.75.5, 0.76.9, 0.80.3, 0.82.1, 0.83.1, 0.83.10, 0.84.1, 0.85.0 and
0.87.1. Rows that cover versions we did not build are inferred from the `fmt` version each release
ships — see below.

#### `fmt` — affects React Native 0.76.9 through 0.83.4

```
Pods/fmt/include/fmt/format-inl.h: error: call to consteval function
'fmt::basic_format_string<...>' is not a constant expression
```

Xcode's Clang tightened how it validates C++20 `consteval`, and the `fmt` version React Native
vendors does not satisfy it — [facebook/react-native#55601](https://github.com/facebook/react-native/issues/55601),
where it is reported against **Xcode 26.4 and later**. We measured it on 26.6 and did not test
earlier releases, so if you are on Xcode 26.0–26.3 you may not be affected.
**Two things have to be true for this to bite you**: the `fmt` your React Native ships must be
11.0.2, *and* your build must compile it from source. That gives:

| React Native | `fmt` | Compiled from source | Affected |
|---|---|---|---|
| 0.76.8 and earlier | 9.1.0 | yes | no — no `consteval` |
| **0.76.9 – 0.83.4** | 11.0.2 | yes | **yes** |
| 0.83.5 and later 0.83.x | 12.1.0 | yes | no |
| 0.84.x | 11.0.2 | **no** — prebuilt binaries | no |
| 0.85 and later | 12.1.0 | no — prebuilt binaries | no |

The bump to `fmt` 12.1.0 landed upstream on 2026-03-19 and reached 0.85 and the 0.83 patch line,
but **not** 0.84, whose last release predates it. 0.84 is fine anyway, for a different reason: from
that version React Native ships its iOS third-party dependencies as prebuilt binaries, so your
build never compiles `fmt` and the version it declares stops mattering.

The boundaries are exact, not rounded: we read `spec.version` from each release's
`third-party-podspecs/fmt.podspec`. `fmt` 9.1.0 holds through **0.76.8**, 11.0.2 starts at
**0.76.9**, and 12.1.0 starts at **0.83.5** — so 0.83.2, 0.83.3 and 0.83.4 are still affected.

We built and confirmed the failure on 0.76.9, 0.80.3, 0.82.1 and 0.83.1, and a clean build on
0.75.5, 0.83.10, 0.84.1, 0.85.0 and 0.87.1. For the releases in between we read the `fmt` version
rather than building them, so the range is exact but their build outcome follows from the
mechanism above.

Until you can upgrade, compile `fmt` as C++17 in your `post_install`:

```ruby
installer.pods_project.targets.each do |t|
  next unless t.name == 'fmt'
  t.build_configurations.each do |c|
    c.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++17'
  end
end
```

> Several community guides suggest defining `FMT_CONSTEVAL=` instead. **That does not work** — we
> verified the define reaches the `pbxproj` and the build still fails. Use the C++17 setting.

#### Yoga — measured on React Native 0.72

```
ReactCommon/yoga/yoga/YGValue.h: error: identifier '_pt' preceded by whitespace in a
literal operator declaration is deprecated [-Werror,-Wdeprecated-literal-operator]
```

Xcode's Clang treats that deprecation as an error. Measured on Xcode 26.6. In your `post_install`:

```ruby
installer.pods_project.targets.each do |t|
  t.build_configurations.each do |c|
    f = c.build_settings['OTHER_CPLUSPLUSFLAGS'] || ['$(inherited)']
    f = [f] unless f.is_a?(Array)
    f << '-Wno-deprecated-literal-operator' unless f.include?('-Wno-deprecated-literal-operator')
    c.build_settings['OTHER_CPLUSPLUSFLAGS'] = f
  end
end
```

### 2. Install

```sh
cd ios
pod install
cd ..
```

### 3. Declare the banking apps

So that Khipu can open your customer's banking app, your `ios/<YourApp>/Info.plist` must declare
these URL schemes. **This goes in your app** — having them in our example is not enough:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>bancochilemipass2</string>
  <string>BciPassApp</string>
  <string>BICEPassApp</string>
  <string>scotiabankgo</string>
  <string>SantanderPassApp</string>
  <string>tupass</string>
  <string>bancoestado</string>
  <string>itau.cl</string>
  <string>SecurityPass</string>
</array>
```

### If you are on React Native older than 0.75

`spm_dependency` does not exist before 0.75, so the plugin falls back to CocoaPods automatically
and you do not need the helper from step 1. The trade-off is that the SDK stays pinned at
`KhipuClientIOS 2.16.5`, the last version published to the CocoaPods trunk. To receive newer SDK
versions you need to upgrade React Native.


## Locale

**Send `locale` explicitly if you need a deterministic language.** The two native SDKs disagree on
the default: on iOS it is hardcoded to `es_CL`, while on Android it follows the device language. The
same payload without `locale` can therefore render in different languages on each platform. This is
a difference between the native SDKs, not something the plugin decides.

## Usage

```typescript
import {
  type KhipuColors,
  type KhipuOptions,
  type KhipuResult,
  startOperation,
} from 'react-native-khipu';

// ...

const result: KhipuResult = await startOperation({
  operationId: '<paymentId>',
  options: {
    title: '<Title to display in the payment process>', // Title for the top bar during the payment process.
    titleImageUrl: '<Image to display centered in the topbar>', // Url of the image to display in the top bar.
    locale: 'es_CL', // Regional settings for the interface language. The standard format combines an ISO 639-1 language code and an ISO 3166 country code. For example, "es_CL" for Spanish (Chile).
    theme: 'light', // The theme of the interface, can be 'dark', 'light' or 'system'
    showFooter: true, // If true, a message is displayed at the bottom with the Khipu logo.
    showMerchantLogo: true, // If true, the merchant's logo is displayed in the top bar.
    showPaymentDetails: true, // If true, the payment code and a link to view the details are displayed.
    skipExitPage: false, // If true, skips the exit page at the end of the payment process, whether successful or failed.
    skipExitSuccessPage: false, // If true, skips the exit page at the end of the payment process only if it was successful.
    colors: {
      lightTopBarContainer: '<colorHex>', // Optional background color for the top bar in light mode.
      lightOnTopBarContainer : '<colorHex>', // Optional color of the elements on the top bar in light mode.
      lightPrimary : '<colorHex>', // Optional primary color in light mode.
      lightOnPrimary : '<colorHex>', // Optional color of elements on the primary color in light mode.
      lightBackground : '<colorHex>', // Optional general background color in light mode.
      lightOnBackground : '<colorHex>', // Optional color of elements on the general background in light mode.
      darkTopBarContainer : '<colorHex>', // Optional background color for the top bar in dark mode.
      darkOnTopBarContainer : '<colorHex>', // Optional color of the elements on the top bar in dark mode.
      darkPrimary : '<colorHex>', // Optional primary color in dark mode.
      darkOnPrimary : '<colorHex>', // Optional color of elements on the primary color in dark mode.
      darkBackground : '<colorHex>', // Optional general background color in dark mode.
      darkOnBackground : '<colorHex>', // Optional color of elements on the general background in dark mode.
    } as KhipuColors
  } as KhipuOptions
})
```

### A note on types

Optional fields are now declared with `?`, so you can just leave out the ones you do not use
instead of passing `undefined`. The `as KhipuOptions` / `as KhipuColors` casts above are no longer
necessary either, though they keep working.

`result` is now a plain `string` instead of a fixed union of literals, so your build will not break
the day the backend adds a new value. Checks like `result === 'OK'` behave exactly as before. The
only code worth revisiting is a variable you had annotated with the old literal union: widen it to
`string`.

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
