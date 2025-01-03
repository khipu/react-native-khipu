# react-native-khipu

Khipu for React Native

## Installation

```sh
npm install react-native-khipu
```


## Android

Add the `Khipu` repository to the allprojects section of `android/build.gradle` file, also Khipu need the kotlin gradle plugin to be, at least, version 1.9.0 and with that to be compiled against the android sdk `34` so please make sure the  `android/build.gradle` file looks like this


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
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0")
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

Install the cocoapods dependencies

```
cd ios
pod install --repo-update
cd ..
```


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
