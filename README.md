# react-native-khipu

Khipu for React Native

## Installation

```sh
npm install react-native-khipu
```


## Android

Add the `Khipu` repository to the allprojects section of `android/build.gradle` file.

**Khipu needs the Kotlin Gradle plugin to be at least `2.0.21`.** The Android SDK
(`com.khipu:khipu-client-android`) is compiled with Kotlin 2.0.21 and uses the
`org.jetbrains.kotlin.plugin.compose` plugin, which only exists from Kotlin 2.0 onwards. An older
Kotlin cannot read that metadata, and Kotlin 1.9.x additionally fails to configure Gradle under
JDK 21 with `Unknown Kotlin JVM target: 21`.

Make sure the `android/build.gradle` file looks like this


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

Also make sure that the kotlin plugin is applied, check the `android/app/build.gradle` file for something like:

```
apply plugin: 'kotlin-android'
```


If you are using jetifier please exclude the `jackson-core` package from it in the `android/gradle.properties` file

```
android.jetifier.ignorelist = jackson-core
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
| 0.74, 0.75 | yes | — | — |
| 0.76, 0.80 | no | `fmt`, `format-inl.h` | see below |
| 0.83, 0.85, 0.87 | yes | — | — |

#### `fmt` — measured on React Native 0.76 and 0.80

```
Pods/fmt/include/fmt/format-inl.h: error: call to consteval function
'fmt::basic_format_string<...>' is not a constant expression
```

Xcode's Clang tightened how it validates C++20 `consteval`, and the `fmt` version React Native
vendors does not satisfy it — [facebook/react-native#55601](https://github.com/facebook/react-native/issues/55601),
where it is reported against **Xcode 26.4 and later**. We measured it on 26.6 and did not test
earlier releases, so if you are on Xcode 26.0–26.3 you may not be affected.
**Fixed in React Native 0.84+**, which bumps `fmt`. We measured this on 0.76 and 0.80; 0.83 and
later build fine. Until you can upgrade, compile `fmt` as C++17 in your `post_install`:

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

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
