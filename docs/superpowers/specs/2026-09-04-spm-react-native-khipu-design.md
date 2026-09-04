# Migración de `react-native-khipu` a SPM y a React Native moderno — Diseño

**Fecha:** 2026-09-04
**Estado:** Decisiones confirmadas. Sondeo ejecutado. Pendiente: plan + ejecución.
**Repo:** `khipu/react-native-khipu`
**Contexto:** tercer eslabón de la migración SPM de Khipu. `KhipuClientIOS` publica SPM desde
`2.16.3` (ver `docs/superpowers/specs/2026-06-28-spm-khipuclientios-design.md` en
`khipu/KhipuClientIOS`). `flutter_khipu` ya migró
(`docs/superpowers/specs/2026-09-04-spm-flutter-khipu-design.md`). `cordova-khipu` y
`capacitor-khipu` están en proceso.

## 1. Objetivo

Dos objetivos que resultaron ser el mismo trabajo:

1. **Que `react-native-khipu` pueda seguir entregando versiones nuevas del SDK después del 2 de
   diciembre de 2026**, cuando el trunk de CocoaPods deja de aceptar podspecs.
2. **Que funcione en React Native moderno** sin romper a los comercios que están atrasados.

### Por qué importa, y por qué ahora

El **2 de diciembre de 2026** el trunk de CocoaPods pasa a read-only de forma permanente
(anuncio de Orta Therox; ensayo de read-only del 1 al 7 de noviembre). Los pods ya publicados
siguen resolviéndose para siempre vía el CDN — **no se rompe ningún build existente**. Lo que
muere es publicar versiones nuevas.

El efecto no se limita a `KhipuClientIOS`: **se congela el árbol completo**. `KhipuClientIOS`
depende de `Socket.IO-Client-Swift`, `Starscream`, `KhenshinSecureMessage` y `KhenshinProtocol`.
Los dos Khenshin son de Khipu — después del 2 de diciembre tampoco se les puede publicar
versiones nuevas. Un fix de seguridad en cualquier eslabón queda inalcanzable por CocoaPods.

Estamos a menos de tres meses. Esto no es trabajo a futuro.

## 2. Estado actual (verificado)

| Ítem | Valor |
|---|---|
| Versión del plugin | `2.14.0` |
| `peerDependencies` | `react: "*"`, `react-native: "*"` — sin piso declarado |
| `devDependencies.react-native` | `0.74.1` |
| RN del `example` | `0.74.1` |
| Última RN estable | **`0.87.1`** — 13 minors de brecha |
| Fuentes iOS | `ios/Khipu.swift`, `ios/Khipu.mm`, `ios/Khipu-Bridging-Header.h` |
| Tipo de módulo (iOS) | Legacy: `RCT_EXTERN_MODULE`, sin codegen |
| Tipo de módulo (Android) | Legacy: `KhipuModule : ReactContextBaseJavaModule`, `KhipuPackage : ReactPackage`, opciones leídas de `ReadableMap` por claves de string |
| `codegenConfig` | ausente |
| Podspec: SDK | `s.dependency "KhipuClientIOS", "2.16.2"` |
| Podspec: New Architecture | `install_modules_dependencies(s)` con rama manual de fallback |
| `react-native-builder-bob` | `0.20.0` (actual: `0.43.0`) |
| `create-react-native-library` | actual `0.63.0` |
| `example/ios` deployment target | `13.4` (4 ocurrencias) |
| `example/ios/.../Info.plist` | **sin `LSApplicationQueriesSchemes`** — verificado, la clave no existe |
| CI | `.github/workflows/ci.yml` con jobs `lint`, `test`, `build-library`, `build-android` y **`build-ios`** (corre `pod install` + `turbo run build:ios`) |
| README | sección `## iOS` con `pod install --repo-update` y nada más |

### Entorno de desarrollo

Xcode 26.6 (build 17F113), Swift 6.3.3, CocoaPods 1.16.2, Node 20.19.4, simuladores iOS 26.5.
Relevante que sea Xcode 26: es donde `spm.rb` documenta su problema de modulemaps duplicados y
donde react-native-firebase necesita desactivar los explicit modules.

### `KhipuClientIOS` (upstream)

| Ítem | Valor |
|---|---|
| Repo SPM | `https://github.com/khipu/KhipuClientIOS.git` |
| SPM disponible desde | `2.16.3` · último tag **`2.16.5`** |
| `platforms` en `Package.swift` | `.iOS(.v13)` |
| `deployment_target` en el podspec | `12.0` |
| Publicado en trunk | sí, hasta `2.16.5` — es la mayor por semver (verificado contra la API de trunk) |
| Recursos | `Bundle.module` bajo `#if SWIFT_PACKAGE` |

### El piso de iOS lo pone React Native, no nosotros

`min_ios_version_supported` en RN 0.87.1 es **`15.1`** (verificado en
`scripts/cocoapods/helpers.rb`). Está muy por encima del piso de `KhipuClientIOS` (12.0 en el
podspec, 13.0 en SPM), así que no hay conflicto en ninguno de los dos caminos.

Consecuencia relevante: con un piso real de iOS 15.1, `UIApplication.shared.windows` está
deprecado **de verdad** para nuestros consumidores modernos, no en abstracto (ver §8).

### Estado de SPM en React Native

Hay dos mecanismos distintos, y conviene no confundirlos:

| | Qué es | Madurez |
|---|---|---|
| **`spm_dependency`** | Helper de podspec (RN ≥0.75). El plugin sigue siendo un pod, pero resuelve una dependencia por SPM en vez de por CocoaPods | Maduro. Lo usa react-native-firebase en producción |
| **`npx react-native spm`** | La app entera prescinde de CocoaPods y consume RN por SwiftPM | **Preview.** Meta: *"not yet recommended for production"* |

Para el segundo camino, la doc interna de RN
(`scripts/spm/__docs__/spm-scripts.md`) es explícita en dos puntos que nos afectan:

1. Si **cualquier** librería autolinkeada no trae `Package.swift`, `spm add`/`update` **falla
   duro** con `error: Package.swift is missing for library "<name>"` y exit code 2.
2. El escape (`npx react-native spm scaffold`) **no sirve para nosotros**:
   > *A library whose sources mix Swift **and** Objective-C/C++ in one target ... can't be
   > scaffolded automatically. Opt it out via `react-native.config.js`
   > (`platforms.ios = null`) or ask the maintainer for a prebuilt xcframework.*

`react-native-khipu` es exactamente ese caso (`Khipu.swift` + `Khipu.mm` en un solo target). Hoy
un comercio en el camino SPM con nuestro plugin instalado queda **bloqueado sin workaround**.

**La limitación es del auto-scaffolder, no de SPM.** SPM no admite lenguajes mezclados en un
target ([SE-0403](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0403-swiftpm-mixed-language-targets.md),
*Returned for Revision*), y el workaround canónico es sub-targets por lenguaje. Un `Package.swift`
escrito a mano con dos targets funciona perfecto **y conserva el `.mm`**. Esto es central: significa
que **no hay que subir el piso a RN 0.79** para tener SPM.

## 3. Decisiones confirmadas

1. **Camino A — `spm_dependency`** para resolver `KhipuClientIOS` desde git. Es lo que saca a
   Khipu de la dependencia del trunk.
2. **RN <0.75 se congela** en la última versión de `KhipuClientIOS` publicada en trunk antes del
   2 de diciembre. Para subir de SDK, esos comercios suben de RN. No se monta Specs repo propio.
3. **Camino B — `Package.swift` propio, marcado como experimental** en el README, alineado con
   el lenguaje de Meta, para no comprometer soporte sobre un formato en rotación.
4. **TurboModule con codegen en las dos plataformas**, manteniendo el `.mm` en iOS. Android entra
   obligatoriamente porque `codegenConfig` es cross-platform (§7).
5. **Arreglar el presenter deprecado** (§8).
6. **`LSApplicationQueriesSchemes` en el example** (§9).

### Sobre el pin exacto y lo que garantiza

Igual que en `flutter_khipu`: el plugin es la compuerta de versiones. El pin exacto garantiza la
versión de `KhipuClientIOS` en sí. Desde `2.16.5` su `Package.swift` fija exactas sus tres
dependencias de producción, así que la brecha es angosta. **Queda abierto `Starscream`**: el
podspec de `KhipuClientIOS` lo fija en `4.0.8`, pero no es dependencia declarada de su
`Package.swift` — llega transitivamente vía `socket.io-client-swift`, que lo declara
`.upToNextMajor(from: "4.0.8")`. Bajo SPM puede resolver a cualquier `4.x`. Limitación conocida
y acotada, heredada del spec de `flutter_khipu`, no un pendiente de este trabajo.

## 4. Sondeo ejecutado

App RN 0.87.1 recién creada, `react-native-khipu` por path local con el podspec modificado a
`spm_dependency` sobre `KhipuClientIOS 2.16.5`, `pod install` **sin `use_frameworks!`** (linking
estático, el default de RN). Desechable, fuera del repo.

### Resultado 1 — el linking estático funciona

| Paso | Resultado |
|---|---|
| `pod install` con `spm_dependency` + estático | ✅ Pasa. Warning, no error |
| Build estático **sin** parche | ❌ `** BUILD FAILED **` |
| Build estático **con** el `gsub` corregido | ✅ `** BUILD SUCCEEDED **`, cero errores |

**No hay que imponerle `use_frameworks! :linkage => :dynamic` a los comercios.** Esa era la
hipótesis de riesgo alto tomada de react-native-firebase, y quedó descartada: su falla dura es
específica de Firebase (muchos pods embebiendo cada uno su `FirebaseCore`), no de
`spm_dependency`. Nosotros somos un pod con un solo producto SPM.

### El bug de React Native 0.87.1 que hay que rodear

El build estático falla así:

```
error: module map file '.../Debug-iphonesimulator/react-native-khipu/react_native_khipu.modulemap'
       not found (in target 'Pods-SpmProbe' from project 'Pods')
```

| | valor |
|---|---|
| Dónde queda el modulemap | `Debug-iphonesimulator/react_native_khipu.modulemap` |
| Qué path referencia el xcconfig | `${PODS_CONFIGURATION_BUILD_DIR}/react-native-khipu/react_native_khipu.modulemap` |

`spm.rb` aplana el build dir del pod para evitar modulemaps duplicados y después intenta
reescribir la referencia en los xcconfig agregados. El `gsub` busca
`"${PODS_CONFIGURATION_BUILD_DIR}/#{pod_name}/#{pod_name}.modulemap"`. Pero CocoaPods nombra el
modulemap con el **module name** (`react_native_khipu`, guiones bajos), no con el **pod name**
(`react-native-khipu`, guiones). El `gsub` nunca calza y la reescritura es un no-op silencioso.

Afecta a **cualquier pod con guión en el nombre**, o sea a casi toda librería de la comunidad RN,
no solo a Khipu.

Corrección verificada (usa `product_module_name` en vez de `name` para el archivo):

```ruby
installer.aggregate_targets.each do |agg|
  agg.xcconfigs.each do |cfg_name, cfg_file|
    %w[OTHER_CFLAGS OTHER_SWIFT_FLAGS].each do |key|
      val = cfg_file.attributes[key]
      next unless val
      new_val = val
      installer.pod_targets.each do |pt|
        new_val = new_val.gsub(
          "${PODS_CONFIGURATION_BUILD_DIR}/#{pt.name}/#{pt.product_module_name}.modulemap",
          "${PODS_CONFIGURATION_BUILD_DIR}/#{pt.product_module_name}.modulemap"
        )
      end
      cfg_file.attributes[key] = new_val if new_val != val
    end
    cfg_file.save_as(agg.xcconfig_path(cfg_name))
  end
end
```

**Costo real para el comercio.** Un plugin no puede inyectarse en el `post_install` de la app, así
que esto tiene que ir en el `Podfile` del comercio. Se publica como helper en el paquete
(`ios/khipu_spm_fix.rb`) y el comercio agrega dos líneas: un `require` y la llamada después de
`react_native_post_install`. **El camino A no es gratis** — pero es mucho más barato que el
`use_frameworks!` que temíamos, y desaparece cuando el fix llegue upstream.

**Acción upstream:** abrir PR a `facebook/react-native` corrigiendo
`rewrite_aggregate_modulemap_references` en `scripts/cocoapods/spm.rb`. Beneficia a toda la
comunidad y nos permite retirar el helper cuando el piso de RN lo permita.

### Resultado 2 — el árbol completo sale de git

SPM resolvió, sin trunk en ninguna parte:

```
KhipuClientIOS · KhenshinProtocolSwift · KhenshinSecureMessage
socket.io-client-swift · Starscream · tweetnacl-swiftwrap
```

Esta es la validación directa del objetivo §1.

### Resultado 3 — los recursos se embeben y funcionan

El `.app` construido contiene:

```
SpmProbe.app/KhipuClientIOS_KhipuClientIOS.bundle/
  Assets.car  Info.plist  khipuClient.html
  PublicSans-{Bold,Medium,Regular,SemiBold}.ttf
  authorize.png  logo-khipu-color.png
```

Coincide exactamente con lo que documentó el spec de `flutter_khipu`. **Descarta la hipótesis del
build phase propio** que react-native-firebase necesitó: la integración SPM a nivel de pod de RN
sí copia el bundle en nuestro caso.

### Resultado 4 — pago real bajo SPM

Operación real lanzada en simulador iOS 26.5. La UI de Khipu renderizó completa: fuentes
PublicSans cargadas, `logo-khipu-color.png` visible en *"Operado por Khipu"*, colores del tema y
el `title` pasado por opciones, y **`v2.16.5`** al pie — la versión resuelta por SPM desde git, no
el pod. El pago se abandonó sin completar.

Esto cierra el paso que el spec de `KhipuClientIOS` dejó pendiente para un consumidor React
Native real.

> **Trampa heredada de la sesión de `flutter_khipu`, no repetir:** nunca verificar comportamiento
> de runtime desde un build con `--no-codesign`. Ese flag produce una firma linker-signed que deja
> al proceso sin acceso al Keychain, todo `SecItem*` devuelve `-34018` y bajo `2.16.4` mataba la
> app a mitad del pago. El sondeo de este spec usó builds normales.
>
> **Es una trampa de testing, no un incidente de campo.** Un build de dispositivo lleva
> `application-identifier` en sus entitlements, que es lo que provee el access group por defecto
> del Keychain — la sesión de Flutter lo comprobó sobre el binario firmado. El problema está
> acotado a entornos que carecen de eso: builds `--no-codesign` y test targets sin host app. La
> app que publica un comercio no lo pisa. No dimensionar nada de este trabajo como si lo fuera.

## 5. Podspec

```ruby
require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-khipu"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/khipu/react-native-khipu.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift}"

  # RN >=0.75 resuelve el SDK desde git y queda inmune al freeze del trunk.
  # RN <0.75 cae al pod, congelado en la ultima version publicada antes del 2026-12-02.
  if respond_to?(:spm_dependency, true)
    spm_dependency(s,
      url: "https://github.com/khipu/KhipuClientIOS.git",
      requirement: { kind: "exactVersion", version: "2.16.5" },
      products: ["KhipuClientIOS"]
    )
  else
    s.dependency "KhipuClientIOS", "2.16.5"
  end

  install_modules_dependencies(s)
end
```

Cambios respecto de hoy:

- `spm_dependency` con fallback, en vez de `s.dependency` a secas.
- **Se elimina la rama manual de New Architecture** (el `else` con `folly_compiler_flags`,
  `React-Codegen`, `RCT-Folly`, etc.). `install_modules_dependencies` la cubre desde RN 0.71 y es
  lo que hace el template actual de `create-react-native-library` (verificado en
  `templates/native-common/*.podspec`). Mantenerla es peso muerto que además puede divergir.
- `folly_compiler_flags` deja de usarse y se borra.

**El `2.16.5` de la rama `else` es el valor de hoy, y hay que reconfirmarlo al momento del
release**: debe ser la última versión publicada en trunk antes del 2026-12-02, que es el piso
permanente de esos comercios. Si entre hoy y el release sale una `2.16.6` o superior y alcanza a
publicarse en trunk, esa es la que va. Ver §13.

## 6. `Package.swift` (experimental)

Dos targets, porque SPM no admite lenguajes mezclados:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "react-native-khipu",
    platforms: [.iOS("15.1")],
    products: [
        .library(name: "react-native-khipu", targets: ["Khipu"])
    ],
    dependencies: [
        .package(url: "https://github.com/khipu/KhipuClientIOS.git", exact: "2.16.5")
    ],
    targets: [
        .target(name: "KhipuObjC", dependencies: [/* headers de RN */]),
        .target(name: "Khipu", dependencies: [
            "KhipuObjC",
            .product(name: "KhipuClientIOS", package: "KhipuClientIOS")
        ])
    ]
)
```

**Esta declaración es un boceto, no está validada.** A diferencia de todo lo demás en este spec,
el camino B no se sondeó. Lo que falta resolver durante la implementación:

- Cómo se declaran las dependencias de headers de React Native. El contrato es **zero-`-I`**: ni
  header search paths ni `unsafeFlags` en el manifiesto. Los headers llegan por product
  dependencies (`ReactNativeHeaders`, `ReactNativeDependenciesHeaders`) — ver
  `scripts/spm/__docs__/spm-header-paths-contract.md`.
- Dónde quedan físicamente las fuentes. SPM espera `Sources/<target>/`; hoy están planas en
  `ios/`. Mover archivos afecta al `source_files` del podspec, que hay que ajustar en el mismo
  cambio.

**El costo de mantención es real y hay que asumirlo con los ojos abiertos.** El scaffolder de RN
0.87.1 va en `SCAFFOLDER_VERSION = 19`, con bumps rompientes documentados en v2, v4, v5, v7, v8,
v9, v10, v11, v12, v13, v18 y v19 — todos en poco tiempo. Un manifiesto escrito a mano queda
marcado como *self-managed* y RN **nunca** lo regenera. Lo mantenemos nosotros contra un blanco
móvil. De ahí que se documente como experimental.

## 7. TurboModule — las dos plataformas

### Codegen es cross-platform: Android entra sí o sí

`codegenConfig` se declara **una sola vez en `package.json`** y alimenta el codegen de iOS y de
Android por igual. No existe una migración limpia de una sola plataforma.

Estado actual del lado Android: `KhipuModule` extiende `ReactContextBaseJavaModule` (legacy),
`KhipuPackage` implementa `ReactPackage` a mano, y las opciones se leen de un `ReadableMap` por
claves de string (`options.getString("titleImageUrl")`, `options.hasKey("skipExitPage")`, …).
El template oficial de `create-react-native-library` para `turbo-module` hace lo contrario:
el módulo Kotlin **extiende la clase generada** (`NativeKhipuSpec`) y el package extiende
`BaseReactPackage`.

Se evaluó y **se descarta** declarar el spec dejando Android en legacy apoyado en la capa de
interop: es una combinación que nadie ejercita y que no se verificó. Migrar solo iOS no es una
opción disponible.

| Archivo | Rol |
|---|---|
| `src/NativeKhipu.ts` | Spec de codegen: `interface Spec extends TurboModule` + `TurboModuleRegistry` |
| `src/index.tsx` | Reexporta, conservando la API pública actual |
| `package.json` | `codegenConfig` con `name`, `type: "modules"`, `jsSrcsDir` |
| `ios/Khipu.h` | `@interface Khipu : NSObject <NativeKhipuSpec>` |
| `ios/Khipu.mm` | `getTurboModule:`, `moduleName`, y delegación a la clase Swift |
| `ios/Khipu.swift` | La implementación, sin cambios de fondo salvo §8 |
| `android/.../KhipuModule.kt` | Pasa a extender `NativeKhipuSpec` en vez de `ReactContextBaseJavaModule` |
| `android/.../KhipuPackage.kt` | Pasa a `BaseReactPackage` con `getReactModuleInfoProvider()` |
| `android/build.gradle` | Bloque `react { }` para que Gradle corra codegen |

### El beneficio que compra, más allá de la modernización

Hoy las claves del contrato JS↔nativo son strings sueltos en tres superficies
(`src/index.tsx`, `ios/Khipu.swift`, `android/.../KhipuModule.kt`) y **nada las verifica**. Un
rename en un lado desactiva esa opción en silencio, sin error de compilación ni de runtime.

Verificación hecha al escribir este spec: **hoy los tres conjuntos coinciden**, en ambas
direcciones. No hay ninguna clave huérfana. No es un bug vivo, es una fragilidad.

Migrar a codegen cierra esa clase de bug **solo en iOS**. Medido corriendo los generadores de RN
0.87.1 sobre un spec candidato con nuestros tipos reales:

| Plataforma | Qué genera codegen | ¿Protege el contrato? |
|---|---|---|
| iOS | `JS::NativeKhipu::KhipuOptions` con accesores tipados (`theme()`, `titleImageUrl()`, …) | **Sí.** Un rename en el spec TS rompe la compilación de ObjC++ |
| Android | `public abstract void startOperation(ReadableMap options, Promise promise)` | **No.** El Java generado no contiene **ninguna** clave de opciones; el módulo las sigue leyendo con `getString("titleImageUrl")` |

Es una asimetría del propio codegen, no algo que podamos configurar: para parámetros de tipo
objeto, el generador de Java pasa el `ReadableMap` sin desarmar.

**Consecuencia para el diseño:** el test de conjuntos de claves **no es una red temporal, es
permanente**, porque es lo único que va a proteger el lado Android. La sesión de `flutter_khipu`
resolvió lo mismo con `test/method_channel_seam_test.dart` — 12 tests, de los cuales seis
verifican que el propio extractor siga mordiendo: si un reformateo rompe el patrón, los conjuntos
colapsan a vacío y comparan iguales, o sea que un extractor roto se ve idéntico a un protocolo
sano. Esa parte es la que hay que copiar con cuidado.

Migrar las dos plataformas juntas sigue siendo lo correcto, pero por la razón de arriba (codegen
es cross-platform), no porque cierre el contrato en ambas.

### Compatibilidad hacia atrás

Verificado leyendo `Libraries/TurboModule/TurboModuleRegistry.js`: `requireModule()` cae a
`NativeModules[name]` cuando no es bridgeless o cuando el interop está activo. **El spec funciona
igual en arquitectura vieja.** El piso real lo pone codegen (RN ≥0.68) y
`install_modules_dependencies` (RN ≥0.71) — ambos por debajo del 0.75 que ya exige
`spm_dependency`, así que no mueven el piso efectivo.

### El trabajo grueso está en los tipos, no en el registro

Codegen es estricto y **no acepta el `NSDictionary` suelto de hoy**. Hay que tipar
`StartOperationOptions`, `KhipuOptions`, `KhipuColors`, `KhipuResult` y `KhipuEvent` como tipos de
codegen. Dos puntos a resolver:

- Los campos opcionales hoy se declaran `string | undefined`. Codegen quiere `?:` o
  `<T> | null`. Es un cambio de declaración, no de forma del objeto en runtime.
- `theme: 'light' | 'dark' | 'system'` es una unión de literales. Hay que confirmar contra la
  versión de codegen de 0.87 si la acepta como enum o si hay que degradarla a `string`.

**La API pública de JS no cambia.** Si algún tipo no sobrevive a codegen tal cual, se ajusta la
declaración manteniendo la forma, y se deja constancia en el CHANGELOG.

### Sin Swift puro, a propósito

`create-react-native-library@0.63.0` **no ofrece Swift para `turbo-module`**: solo `kotlin-objc` o
`cpp` (verificado — el generador rechaza `--languages kotlin-swift` para ese tipo, y no existe
template `swift-library`). La forma canónica es ObjC++ conformando el protocolo generado. Por eso
el `.mm` se queda: es lo correcto, no una concesión.

Se evaluó y **se descarta** eliminar el `.mm` registrando desde Swift con
`codegenConfig.ios.modulesProvider`: exige **RN ≥0.79** y no compra nada, porque la separación en
dos targets ya resuelve SPM.

## 8. El presenter y el delay de 1 segundo

### Qué hay hoy

```swift
guard let presenter = UIApplication.shared.windows.filter({$0.isKeyWindow}).first?.rootViewController else {
    reject("NO_OPERATION_ID", "No rootViewController found", NSError())
    return
}
presenter.presentedViewController?.dismiss(animated: false)

DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    // ... KhipuLauncher.launch(presenter: presenter, ...)
}
```

### De dónde salió

Entre el 30 de agosto y el 3 de septiembre de 2024 hubo cuatro commits peleando lo mismo:
`b13421a` *"use native rootViewController instead of RCN one"*, `60b1c36`, `5ef67b2` *"using main
rootViewController as presenter for iOS"* y **`594813a` *"fix: dismiss presentedViewController
before calling Khipu"***, que introdujo el `dismiss` y el delay juntos.

Ninguno tiene cuerpo en el mensaje, así que lo que sigue es **lectura del código, no algo
documentado**: el delay existe para **esperar a que termine el `dismiss`**. `dismiss(animated:
false)` es asíncrono igual — termina en un turno posterior del runloop aunque no anime — así que
presentar inmediatamente después seguía chocando con *"already presenting"*. En vez de usar
`dismiss(animated:completion:)` se puso un timer fijo. El `asyncAfter` envuelve exactamente la
llamada a `launch` y nada más en ese bloque depende del tiempo.

### Los tres defectos

1. **Un segundo muerto en cada pago**, incluso sin ningún modal que cerrar — el caso normal.
2. **Le cerramos la UI al comercio** sin avisar. Y `presentedViewController?.dismiss` cierra un
   solo nivel: modales anidados quedan a medias.
3. El segundo es una apuesta. En un equipo lento o con modales anidados el `dismiss` tarda más y
   el launch falla igual.

A eso se suma que `UIApplication.shared.windows` está deprecado desde iOS 15 (*"Use
UIWindowScene.windows on a relevant window scene instead"*) y reporta ventanas de todas las
escenas conectadas: en una app multi-scene puede devolver la equivocada o ninguna.

### El arreglo

Presentar sobre el controlador **más alto** en vez de sobre el `rootViewController`. Sin
`dismiss` no hay nada que esperar, y el delay desaparece porque desaparece su causa.

```swift
private static func presenter() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first,
          let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
    else { return nil }

    var controller = window.rootViewController
    while let presented = controller?.presentedViewController {
        controller = presented
    }
    return controller
}
```

Válido con piso iOS 13 (`connectedScenes` es 13+; `UIWindowScene.keyWindow` es 15+ y se evita a
propósito), así que sirve igual si algún día bajamos el piso.

**Privado al tipo del plugin, no una extensión de `UIViewController`.** La doc de iOS de Khipu
sugiere una extensión `topMostViewController()`, pero un plugin enlazado estáticamente que mete
ese nombre en la app del comercio puede colisionar con el suyo.

Crédito: lo levantó la sesión de `flutter_khipu`. **Ya está mergeado y liberado allá** — PR #13,
commit `667714b`, publicado en `flutter_khipu 1.7.1`, así que es un diff que se puede leer en vez
de una descripción. Verificado contra nuestro código, donde el síntoma es distinto y peor:
Flutter falla en silencio, nosotros destruimos estado de UI ajeno.

Allá se validó **en dispositivo físico** (iPhone 13, iOS 26.6.1, build release con firma real),
presentando un controlador transparente al toque para que el root ya estuviera presentando y
lanzando el pago automáticamente: cero ocurrencias de *"already presenting"* / *"Attempt to
present"*, y el flujo llegó a `OPERATION_SUCCESS`. Bajo el código viejo esa presentación habría
sido rechazada. Nuestra validación equivalente es el paso 6 del gate (§11).

## 9. Example y `Info.plist`

- `example` a RN **0.87.1**.
- Deployment target de `13.4` a `15.1`, que es lo que impone RN 0.87.
- **`LSApplicationQueriesSchemes`** con las nueve schemes. Verificadas de forma independiente
  contra la documentación de Khipu vía el MCP de docs: las páginas de iOS, Flutter, Capacitor,
  Cordova y **React Native** coinciden en la lista y el orden.

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

Dos valores son los actuales de entradas que están obsoletas en otras partes:
`bancochilemipass2` (no `bancochilemipass`) y `scotiabankgo` (no `keypass`). El propio example de
`KhipuClientIOS` cargaba el par viejo y se corrigió en `2.16.5`: **copiar desde la doc, no desde
otro example.**

> Si la actualización del example regenera `example/ios`, esto va como **paso de la
> regeneración**, no como parche posterior. La sesión de `capacitor-khipu` descubrió que el suyo
> se reconstruye dos veces, lo que habría borrado un plist parchado en silencio.

También va al README una sección de iOS que le diga al comercio que debe declarar estas schemes
en **su** app: el example es referencia, pero no todos lo miran.

## 10. CI

`.github/workflows/ci.yml` tiene un job `build-ios` que corre `pod install` y
`turbo run build:ios`, con caché de `example/ios/Podfile.lock` y `**/ios/Pods`.

Cambios necesarios:

- El caché de pods debe considerar además el `Package.resolved` que genera SPM, o se sirve un
  árbol de dependencias viejo.
- Agregar la resolución SPM al job (la primera build baja los checkouts desde git).
- El helper del §4 debe estar aplicado en el `Podfile` del example para que el job pase.

## 11. Gate de validación

**Paso 0 — línea base, antes de tocar nada.** Con RN 0.74.1 y el plugin sin modificar, correr el
example en iOS y Android y dejar constancia de que funcionan. Es gratis ahora y después ya no se
puede.

1. **Regresión CocoaPods, camino nuevo** — `pod install` + build del example en 0.87.1 con
   linking estático. Debe pasar con el helper aplicado.
2. **Linking dinámico** — repetir con `USE_FRAMEWORKS=dynamic`. **No se sondeó**; se espera que
   funcione y que además evite el bug del §4 por tomar otra rama de `spm.rb`, pero hay que
   comprobarlo. Si falla, es un hallazgo nuevo y hay que documentarlo en el README.
3. **Fallback sin `spm_dependency`** — verificar que la rama `else` del podspec resuelve. Se
   puede forzar con un RN 0.74 o simulando que el helper no existe.
4. `pod lib lint react-native-khipu.podspec --configuration=Debug --skip-tests`
5. **Pago real bajo SPM** con render de fuentes, colores e imágenes. Los pasos 1-4 prueban que
   compila; **este prueba que funciona**. Builds normales, nunca `--no-codesign`.
6. **El presenter, con un modal arriba.** Levantar un modal propio en el example y llamar
   `startOperation`. Debe presentar Khipu **encima**, sin cerrar el modal, y **sin el segundo de
   espera**. Es la verificación de que §8 arregla lo que dice arreglar.
7. **`openApp` en dispositivo físico.** Con las schemes declaradas, confirmar que `canOpenURL`
   resuelve y que una app bancaria **efectivamente abre**.

   > Esto merece un párrafo aparte porque el estado real es peor de lo que parece. Las nueve
   > schemes son correctas **por inspección** contra la documentación, y así se verificaron acá
   > (§9). Pero según la sesión de `flutter_khipu`, `openApp` **nunca se ha ejercitado en runtime
   > en ninguna de las cuatro integraciones** — nadie ha visto abrirse una app de banco. Y como
   > nuestro example hoy no declara **ninguna** scheme, somos el repo donde la brecha es más
   > ancha. Si logramos una corrida en dispositivo, seríamos los primeros en cerrarla para
   > cualquiera de los cuatro plugins. Requiere hardware con apps bancarias instaladas, así que
   > si no se consigue, **dejarlo escrito como no verificado** en vez de darlo por bueno.

8. **Android: TurboModule funcionando.** El example en Android corriendo un pago completo con el
   módulo migrado a `NativeKhipuSpec`. No es "correr Android por si acaso" — Android cambia en
   este trabajo (§7) y necesita su propia validación de extremo a extremo.
9. **Paridad de opciones entre plataformas.** Con el mismo `startOperation` (título, colores,
   `skipExitPage`, `theme`), confirmar que iOS y Android se comportan igual. Es la verificación
   de que el contrato de claves sobrevivió a la migración a codegen en los dos lados.
10. `yarn lint`, `yarn typecheck`, `yarn test`.

## 12. Riesgos

| Riesgo | Nivel | Mitigación |
|---|---|---|
| Que no se publique en trunk la versión final de `KhipuClientIOS`, `KhenshinProtocol` y `KhenshinSecureMessage` antes del **2026-12-02** | **Alto, y no depende de este repo** | Es el piso permanente de los comercios en RN <0.75. Decidir cuál es y publicarla con holgura, no el 1 de diciembre. Ver §13 |
| El helper del `Podfile` es un paso de instalación nuevo para el comercio | Conocido y aceptado | Documentado en el README. Se retira cuando el fix llegue upstream a RN |
| Que codegen no acepte algún tipo de las opciones actuales | **Descartado empíricamente** | Se corrió el parser y los cuatro generadores de RN 0.87.1 sobre un spec candidato con los tipos reales: pasan la unión de literales de `theme`, los objetos anidados, el array de `events` y los diez opcionales. Ver §7 |
| Que un rename de clave desactive una opción en silencio **en Android**, donde codegen no protege nada | **Permanente, no se cierra con la migración** | El test de conjuntos de claves (§7) es la única defensa y queda como artefacto permanente, no como red temporal. Más el paso 9 del gate como verificación de paridad |
| Que `openApp` no funcione pese a las schemes correctas — nunca se ha visto abrir un banco en ninguna integración | **Desconocido, no bajo** | Paso 7 del gate, en dispositivo físico. Si no hay hardware, se documenta como no verificado en vez de asumirlo |
| Que el `Package.swift` del §6 quede desactualizado con RN 0.88+ | **Alto, aceptado** | Por eso va marcado experimental. `SCAFFOLDER_VERSION` va en 19 con muchos bumps rompientes |
| Que el linking dinámico falle | Bajo | Paso 2 del gate |
| Un comercio que declare `KhipuClientIOS` directo por SPM con `from:` choca con nuestro `exact:` | Conocido y aceptado | Consecuencia deliberada de la política de versiones |
| Divergencia de `Starscream` entre CocoaPods y SPM | Bajo | §3. Heredado, acotado |
| El salto de 13 minors del example traiga ruido propio | Medio | Paso 0 del gate da la línea base para distinguir qué rompió qué |

## 13. Acción externa y urgente

**Publicar en el trunk de CocoaPods la versión final de `KhipuClientIOS`, `KhenshinProtocol` y
`KhenshinSecureMessage` antes del 2 de diciembre de 2026.** No es parte de este repo, pero este
diseño depende de ello: es lo que van a recibir para siempre los comercios en RN <0.75. Hoy
`KhipuClientIOS 2.16.5` está en trunk y es la mayor por semver.

## 14. Fuera de alcance

- **El lado Gradle de Android.** El SDK de Android (`com.khipu:khipu-client-android`) se sigue
  resolviendo por Maven y no le afecta nada del freeze de CocoaPods. Lo que sí cambia en Android
  es el módulo, por codegen (§7).
- **Specs repo propio de Khipu.** Evaluado y descartado en favor de congelar RN <0.75 (§3.2).
- **Subir `react-native-builder-bob`** de 0.20 a 0.43. Cambia el formato de salida JS (campo
  `exports`, ESM) y puede romper bundlers viejos. Merece su propio cambio, hecho con intención.
- **`spm_dependency` como opt-in documentado por variable del Podfile** (modelo
  `$RNFirebaseDisableSPM`). No hace falta: el fallback por `respond_to?` cubre el caso.
- **Migrar la app de ejemplo a la New Architecture explícitamente.** Es el default desde 0.76; se
  hereda del template.

## 15. Referencias

- CocoaPods, plan de read-only: `https://blog.cocoapods.org/CocoaPods-Specs-Repo/`
- RN 0.87: `https://reactnative.dev/blog/2026/08/11/react-native-0.87`
- RN, doc interna de SwiftPM: `packages/react-native/scripts/spm/__docs__/` en `facebook/react-native`
- RN, `spm_dependency`: `packages/react-native/scripts/cocoapods/spm.rb` · PR `facebook/react-native#44627`
- react-native-firebase, iOS SPM: `docs/ios-spm.mdx` en `invertase/react-native-firebase`
- SE-0403, targets de lenguaje mezclado: `https://github.com/swiftlang/swift-evolution/blob/main/proposals/0403-swiftpm-mixed-language-targets.md`
- Doc de Khipu, React Native: `https://docs.khipu.com/payment-solutions/instant-payments/khipu-client-react-native`
- Spec upstream: `khipu/KhipuClientIOS` → `docs/superpowers/specs/2026-06-28-spm-khipuclientios-design.md`
- Spec hermano: `khipu/flutter_khipu` → `docs/superpowers/specs/2026-09-04-spm-flutter-khipu-design.md`
- Presenter: PR #13 en `khipu/flutter_khipu`, mergeado como `667714b`, liberado en `1.7.1`
- Test de contrato de claves: `test/method_channel_seam_test.dart` en `khipu/flutter_khipu`
