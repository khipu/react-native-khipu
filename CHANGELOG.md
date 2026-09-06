# Changelog

## 3.0.2

### Requisitos de Android que faltaban en la documentación

Esta versión es principalmente documentación. Si `3.0.1` te funciona, **no
necesitas actualizar**: no hay cambios de comportamiento en las versiones de
React Native donde ya andaba.

Lo que sí cambia es que ahora el README advierte tres cosas que antes te
enterabas al chocar contra un error que no menciona a Khipu por ningún lado.

**`compileSdk` 34 o superior.** El SDK de Android arrastra Jetpack Compose
1.7.6, que exige que quien lo consume compile contra API 34 o posterior. Con
menos, el build falla en `:app:checkDebugAarMetadata`.

**El paso de jetifier no es opcional en React Native ≤ 0.74.** Ya estaba
documentado, pero redactado como "si usas jetifier" — y resulta que esos
templates lo traen activo de fábrica. Sin la línea en `android/gradle.properties`
el build falla así:

```
Failed to transform jackson-core-2.15.2.jar using Jetifier.
Reason: IllegalArgumentException, message: Unsupported class file major version 63
```

```
android.jetifier.ignorelist = jackson-core
```

Verificado en React Native 0.74.7: agregar esa línea es el único cambio que hace
pasar el build.

**React Native 0.72 no está soportado en Android.** En iOS funciona. En Android
no, y no es algo que podamos arreglar: llegar al `compileSdk` que exige Compose
requiere un Android Gradle Plugin más nuevo, que requiere Gradle 8.9, y el
gradle-plugin de React Native 0.72 no compila ahí. Lo verificamos con
`react-native-khipu` desinstalado y el build falla igual.

Si estás en 0.72 y publicas en Google Play, de todas formas necesitas subir de
React Native: desde el **31 de agosto de 2026** Play exige `targetSdk 36`, que
una app en 0.72 no puede alcanzar por la misma cadena.

### Un arreglo de build defensivo

El módulo de Android no fijaba el `jvmTarget` de Kotlin, así que tomaba por
defecto la versión del JDK de quien compilara. React Native fija el de Java por
su cuenta —11 en 0.72, 17 desde 0.73—, y cuando no coinciden el build falla con
`Inconsistent JVM-target compatibility detected`. En los templates modernos
coincidían por casualidad.

Ahora el plugin sigue al Java que aplique React Native, en vez de depender del
JDK del entorno. **No cambia nada si tu build ya funcionaba.**

### Verificado con pagos reales

A diferencia de versiones anteriores, esta se midió levantando un pago de verdad
en pantalla, no solo compilando:

| React Native | iOS | Android |
| --- | --- | --- |
| 0.74, 0.75, 0.76, 0.80, 0.83, 0.85, 0.87 | pago | pago |
| 0.72 | pago | no compila |

Cada casilla es una app recién creada, con el paquete instalado desde npm y
siguiendo la documentación pública.


## 3.0.1

### Corrige un bug de 3.0.0 que rompía el build en algunas versiones de React Native

Si actualizaste a `3.0.0` y tu build de iOS empezó a fallar con
`module map file ... not found`, **era culpa nuestra** y esta versión lo corrige.
No tienes que cambiar nada en tu `Podfile`: basta con actualizar.

El helper `khipu_fix_spm_modulemaps` reescribía la referencia al modulemap de
todos los pods, sin comprobar si React Native realmente lo necesitaba. React
Native tiene dos caminos según cómo quede el pod, y solo uno requiere la
corrección; en el otro, reescribir apuntaba a un archivo inexistente y rompía un
build que funcionaba.

Verificado instalando desde npm en apps limpias:

| React Native | Con 3.0.0 | Con 3.0.1 |
| --- | --- | --- |
| 0.75 | falla | **compila** |
| 0.85 | falla | **compila** |
| 0.87 | compila | **compila** |

El helper ahora también informa lo que hace durante `pod install`, para que un
problema así no vuelva a pasar inadvertido:

```
[Khipu] Ningun pod fue aplanado por spm.rb; no hay modulemaps que corregir.
[Khipu] Corrigiendo la referencia al modulemap de: react-native-khipu
```


## 3.0.0

### ⚠️ Acción requerida en React Native ≥ 0.75

**Si no haces este cambio, tu build de iOS va a fallar** con
`module map file ... not found`, un error que no dice nada sobre su causa.

Agrega esto arriba de tu `ios/Podfile`:

```ruby
require File.join(
  File.dirname(`node --print "require.resolve('react-native-khipu/package.json')"`),
  "ios/khipu_spm_fix.rb"
)
```

y dentro de tu `post_install`, **después** de `react_native_post_install`:

```ruby
post_install do |installer|
  react_native_post_install(installer, config[:reactNativePath])

  khipu_fix_spm_modulemaps(installer)
end
```

El orden importa: `react_native_post_install` es quien corre la reescritura que
esto corrige.

Es un bug de React Native, no de Khipu — el `gsub` de `scripts/cocoapods/spm.rb`
usa el nombre del pod donde CocoaPods escribe el nombre del módulo, así que la
reescritura del modulemap queda en un no-op silencioso. Afecta a cualquier pod
con guión en el nombre. Cuando el arreglo llegue a React Native, estas dos
líneas se retiran.

**En React Native < 0.75 no tienes que hacer nada.**

### Por qué este cambio

El **2 de diciembre de 2026** el trunk de CocoaPods deja de aceptar versiones
nuevas. Eso no rompe ningún build existente, pero congela el árbol de
dependencias completo de Khipu: `KhipuClientIOS`, `KhenshinProtocol` y
`KhenshinSecureMessage`. Desde esta versión, React Native ≥ 0.75 resuelve el SDK
directamente desde git con Swift Package Manager, y queda fuera de ese
congelamiento.

En React Native < 0.75 el plugin cae automáticamente a CocoaPods, con el SDK
fijo en `KhipuClientIOS 2.16.5` — la última publicada en el trunk. Para recibir
versiones nuevas del SDK hay que actualizar React Native.

### Requisito de Xcode

Apple exige **Xcode 26** para subir a App Store Connect desde el 28 de abril de
2026, así que si publicas tu app ya lo cumples. Ahí el enlazado estático —el
default de React Native— funciona y **no necesitas `use_frameworks!`**.

Si por alguna razón sigues en Xcode 16, el enlazado estático falla con
`duplicate symbol`. La salida es agregar a tu `Podfile`:

```ruby
use_frameworks! :linkage => :dynamic
```

### Cambios que rompen

- **El plugin ya no cierra el modal que tengas presentado.** Antes, si llamabas
  a `startOperation` con una pantalla propia arriba, el plugin la cerraba sin
  avisar y esperaba un segundo fijo antes de mostrar Khipu. Ahora Khipu se
  presenta encima y tu pantalla sobrevive. Además desaparece ese segundo de
  espera, que ocurría en **todos** los pagos, hubiera modal o no.
- **`exitUrl` pasa de `string` a `string | undefined`.** El tipo anterior era
  incorrecto: en pagos reales llega vacío. Si usas `strict`, TypeScript te va a
  señalar los usos que asumían que siempre venía.
- **El código de error `NO_OPERATION_ID` pasa a `NO_PRESENTER`** cuando no hay
  ningún controlador disponible para presentar. El código anterior era
  engañoso: reportaba un problema de `operationId` en un fallo que no tenía
  nada que ver.

### Otros cambios

- `KhipuClientIOS` sube de `2.16.2` a `2.16.5`.
- El `Info.plist` de la app de ejemplo declara las nueve `LSApplicationQueriesSchemes`
  de los bancos chilenos, que faltaban. **Recuerda que también deben estar en tu
  app** — tenerlas en el ejemplo no te sirve.
- El README corrige la versión mínima del plugin de Kotlin, que decía `1.9.0`
  cuando el SDK de Android exige `2.0.21` o superior.
- Se documenta que hay que mandar `locale` explícito si necesitas un idioma
  determinista: iOS lo fija en `es_CL` y Android sigue el idioma del teléfono.
- La app de ejemplo sube a React Native 0.87.1.

### Sin cambios

La firma de `startOperation`, la forma del objeto que resuelve, y el lado
Android del plugin.
