# Matriz de pagos por versión de React Native

**Fecha:** 2026-09-06
**Plugin:** `react-native-khipu@3.0.1` instalado **desde npm**
**Entorno:** Xcode 26.6, CocoaPods 1.16.2, Node 20.19.4, macOS arm64
**Android:** emulador Pixel 9 Pro, API 36, JDK 21 (JDK 17 solo en 0.72)
**iOS:** simulador iPhone 16 Pro

Complementa a [`matriz-versiones-2026-09-05.md`](matriz-versiones-2026-09-05.md), que verificó que
**compila**. Esta verifica que **funciona**: que un pago real levante en pantalla, versión por
versión, en las dos plataformas.

Cada casilla es una app recién creada con `@react-native-community/cli init`, `npm install
react-native-khipu@3.0.1`, y los pasos de integración tomados de
`docs.khipu.com/payment-solutions/instant-payments/khipu-client-react-native` — no del README.
Un solo `operationId` reutilizado en todas.

## Resultados

| RN | Rama | iOS | Android | SDK iOS | SDK Android | APK |
|---|---|---|---|---|---|---|
| 0.87.1 | SPM | ✅ pago | ✅ pago | 2.16.5 | 2.27.0 | 136 MB |
| 0.85.0 | SPM | ✅ pago | ✅ pago | 2.16.5 | 2.27.0 | 130 MB |
| 0.83.10 | SPM | ✅ pago | ✅ pago | 2.16.5 | 2.27.0 | 124 MB |
| 0.80.3 | SPM | ✅ pago (`fmt`) | ✅ pago | 2.16.5 | 2.27.0 | 116 MB |
| 0.76.9 | SPM | ✅ pago (`fmt`) | ✅ pago | 2.16.5 | 2.27.0 | 126 MB |
| 0.75.5 | SPM | ✅ pago | ✅ pago | 2.16.5 | 2.27.0 | 69 MB |
| 0.74.7 | pod | ✅ pago | ✅ pago | 2.16.5 | 2.27.0 | 62 MB |
| 0.73.11 | pod | ✅ pago | ✅ pago | 2.16.5 | 2.27.0 | 39 MB |
| 0.72.17 | pod | ✅ pago (Yoga) | ❌ **no compila** | 2.16.5 | — | — |

**Ocho de nueve versiones levantan un pago real en las dos plataformas.** 0.73.11 se midió el
mismo día contra `3.0.2`, para fijar el piso real del soporte; las otras ocho contra `3.0.1`. La única falla es
Android en 0.72, analizada abajo.

En la rama SPM se resolvieron los tres paquetes: `KhipuClientIOS 2.16.5`,
`KhenshinProtocolSwift 1.0.60` y `KhenshinSecureMessage 1.4.1`. Son las versiones que deben quedar
publicadas en el trunk de CocoaPods antes del **2026-12-02**.

## Cómo se midió cada señal

No alcanza con que la app no se caiga: hay que distinguir la UI de Khipu de una pantalla en blanco,
del harness sin lanzar, y de la pantalla roja de error de React Native.

**Android — dos señales independientes:**

1. `dumpsys activity activities | grep topResumedActivity` conteniendo
   `com.khipu.client.KhipuActivity`.
2. El ciclo de vida en `logcat`: `KhipuActivity: onCreate/onStart/onResume` y
   `ActivityTaskManager: Displayed <pkg>/com.khipu.client.KhipuActivity`.

**iOS — dos señales independientes**, porque el SDK de iOS no loguea ciclo de vida como el de
Android:

1. Clasificación de la captura por color (ver abajo).
2. Tráfico de red en el log unificado: la conexión a `khenshin-ws.khipu.com/socket.io/` —que es la
   sesión de pago estableciéndose— más la descarga del avatar del comercio desde
   `avatars.khipu.com`.

Además se verificó **a ojo** la captura de 0.87.1 en ambas plataformas y la de 0.72.17 en iOS,
cubriendo las dos ramas del podspec. Las 16 capturas se agrupan de forma consistente: iOS entre
177 y 181 KB, Android entre 126 y 128 KB.

### El tamaño del PNG no sirve como señal

La sesión anterior usaba "captura > 140 KB" como indicador de pago en iOS, porque la UI de Khipu
ronda los 176 KB. **Ese umbral es falsable en la dirección peligrosa**: la pantalla roja de LogBox
pesa **493 KB**, así que un error de bundle se registra como pago exitoso. Pasó en la primera
corrida de este barrido y habría producido ocho falsos positivos.

Se reemplazó por una clasificación de color (`sips` → BMP → conteo de píxeles) que distingue tres
estados y se calibró contra capturas conocidas de ambos tipos:

| Clase | Criterio | Significado |
|---|---|---|
| `ERROR_RN` | >35% rojo | pantalla de LogBox |
| `HARNESS` | >35% magenta | el pago no se abrió |
| `PAGO_PROBABLE` | >25% claro | UI de Khipu |

Y una precondición que hace innecesaria la mitad del problema: **exigir que `index.bundle`
devuelva 200** y contenga `react-native-khipu` antes de interpretar ninguna captura.

## La falla: Android en React Native 0.72

Cuatro bloqueos encadenados, cada uno descubierto al resolver el anterior. Los dos atribuidos se
verificaron **con control**, desinstalando `react-native-khipu` y confirmando que el resultado
cambia (o no).

| # | Configuración | Falla | De quién |
|---|---|---|---|
| 1 | Template de fábrica, JDK 21 | Gradle 8.0.1 no corre en JDK 21; muere parseando `settings.gradle` | entorno (RN 0.72 requiere JDK 17) |
| 2 | Template de fábrica, JDK 17 | `androidx.compose.ui:ui-android:1.7.6` exige `compileSdk 34`; el template trae 33 | **Khipu** — sin el plugin, `BUILD SUCCESSFUL` |
| 3 | `compileSdk` 34 o 36 | `Inconsistent JVM-target compatibility`: Java 11 contra Kotlin 17 | **Khipu** — corregido, ver abajo |
| 4 | `compileSdk 36` + AGP 8.7.2 + Gradle 8.9 | el gradle-plugin de RN 0.72 no compila: `Unresolved reference: serviceOf` | **React Native** — sin Khipu falla idéntico |

El bloqueo 2 llega por el SDK Android de Khipu, que arrastra Compose 1.7.6. El 4 es un muro de
React Native: `org.gradle.configurationcache.extensions.serviceOf` desapareció en Gradle 8.5+, y
`@react-native/gradle-plugin` de 0.72 todavía lo importa.

**Conclusión: no es corregible desde el plugin.** Llegar a `compileSdk` 36 exige AGP 8.6+, que
exige Gradle 8.9+, donde el tooling de RN 0.72 no compila.

### Y hay un problema anterior al nuestro

Desde el **31 de agosto de 2026** Google Play exige `targetSdk 36` para apps nuevas y
actualizaciones ([política](https://developer.android.com/google/play/requirements/target-sdk)).
Por la cadena de arriba, **una app en RN 0.72 no puede alcanzar ese target**, con Khipu o sin él.

Es decir: decir "Khipu no soporta RN 0.72 en Android" es cierto pero engañoso. El comercio en
RN 0.72 ya no puede publicar en Play, y ese problema es anterior y mayor.

## El arreglo de `jvmTarget`

El bloqueo 3 sí era nuestro. `android/build.gradle` fijaba `compileOptions` pero no
`kotlinOptions.jvmTarget`, así que el target de Kotlin tomaba por defecto **la versión del JDK de
quien compila**. El plugin de Gradle de React Native fija el de Java por su cuenta —11 en 0.72, 17
desde 0.73—, y cuando no coinciden el build falla.

En los templates modernos coincidía por casualidad. Se corrige resolviéndolo en `afterEvaluate`,
leyendo lo que React Native haya aplicado, en vez de fijar un número que rompería la otra punta
del rango soportado.

## En RN 0.73 el `kotlinVersion` del `ext` es decorativo

Hallazgo de la medición de 0.73.11, y vale para la documentación. El template declara

```groovy
ext { kotlinVersion = "1.8.0" }
dependencies { classpath("org.jetbrains.kotlin:kotlin-gradle-plugin") }   // sin version
```

o sea que la version del plugin de Kotlin **la resuelve React Native**, no el `ext`. Subir
`kotlinVersion` —que es el reflejo natural, y lo que dice el texto de la doc— no tiene ningun
efecto: el modulo sigue compilando con Kotlin 1.8 y falla al leer la metadata 2.0.0 del SDK
Android con `The binary version of its metadata is 2.0.0, expected version is 1.8.0`.

Lo que funciona es poner la version explicita en el `classpath`, que es lo que el ejemplo del
README ya mostraba sin decirlo. Con eso, 0.73.11 levanta el pago.

Primero medimos 0.73 con el parche subiendo solo el `ext` y lo registramos como falla. Era un
error del arnes, no del plugin: la instruccion de la doc no se habia aplicado de verdad.

## Casillas abiertas

- **`openApp` y las nueve URL schemes.** Se declaran en ambas plataformas siguiendo la doc, pero
  el pago se detiene en "Ingresa tu email" y nunca abre una app bancaria. Sigue sin verificarse en
  ninguna de las cuatro integraciones de Khipu.
- **Builds de `release` y las reglas de proguard.** Todo se midió en `debug`.
- **Dispositivo físico.** Todo fue simulador y emulador.
- **Un solo `operationId`,** nunca llevado más allá de la pantalla de email.
- **`apply plugin: 'kotlin-android'`.** La doc pide comprobarlo; los builds pasaron, así que los
  templates lo traen, pero no se ejercitó como paso.
