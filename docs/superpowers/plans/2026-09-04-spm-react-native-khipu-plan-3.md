# Plan 3 — `Package.swift` experimental

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que una app React Native que prescinde de CocoaPods (`npx react-native spm`) pueda
consumir `react-native-khipu`, en vez de quedar bloqueada sin workaround.

**Architecture:** Un `Package.swift` con dos targets — uno Clang para el `.mm` y uno Swift que
depende de él — porque SPM no admite lenguajes mezclados en un target. Las rutas y productos de
React Native **se obtienen corriendo el scaffolder de RN**, no se escriben a mano: codifican el
layout interno de RN y se han movido varias veces.

**Tech Stack:** SwiftPM · React Native 0.87.1 (`npx react-native spm`) · Swift 6.3 / ObjC++

**Spec:** `docs/superpowers/specs/2026-09-04-spm-react-native-khipu-design.md` §6

**Depende de:** Plan 1 y Plan 2 completos. El manifiesto declara el producto `ReactAppHeaders` del
paquete de codegen, que solo existe si el módulo ya es un TurboModule.

## Global Constraints

- **Esto se documenta y se libera como experimental.** El propio React Native dice de su soporte
  SwiftPM: *"the commands, flags, generated layout, and distribution model may change in future
  releases, and it is not yet recommended for production"*. Nuestro README debe decir lo mismo.
- **CocoaPods sigue siendo el camino soportado.** Nada de este plan puede cambiar el
  comportamiento de un comercio que usa `pod install`. Si algo lo cambia, está mal hecho.
- **El manifiesto se genera, no se inventa.** Las líneas `.package(path: ...)` que apuntan a
  `xcframeworks` y al paquete de codegen dependen del layout que arma el autolinker. Sacarlas de
  una corrida real del scaffolder, nunca de este documento ni de memoria.
- **Un manifiesto escrito a mano queda marcado como *self-managed* y RN nunca lo regenera.** Lo
  mantenemos nosotros. `SCAFFOLDER_VERSION` iba en 19 en 0.87.1, con bumps rompientes en v2, v4,
  v5, v7, v8, v9, v10, v11, v12, v13, v18 y v19.
- **Las rutas relativas del manifiesto se resuelven desde el symlink `libs/<SwiftName>`** que crea
  el autolinker, no desde la ubicación real del paquete. Es lo que permite que un manifiesto
  commiteado funcione desde `node_modules`.

---

## Task 1: Obtener el manifiesto de referencia desde el scaffolder

Nuestra librería **no se puede scaffoldear** — mezcla Swift y ObjC++ en un target y el scaffolder
lo rechaza explícitamente. Pero sí se puede scaffoldear una copia sin el Swift, y eso entrega la
verdad sobre productos y rutas para esta versión de RN.

**Files:**
- Create: `docs/superpowers/plans/spm-manifest-reference.md` (hallazgos, no código de producción)

**Interfaces:**
- Consumes: nada.
- Produces: el archivo de referencia con las líneas exactas `.package(...)` y `.product(...)`, los
  valores de `publicHeadersPath` y el `swift-tools-version` que emite RN 0.87.1. Task 2 copia esos
  valores literalmente.

- [ ] **Step 1: Armar una app RN 0.87.1 desechable con la librería por path**

```bash
SCRATCH=$(mktemp -d)
cd "$SCRATCH"
npx -y @react-native-community/cli@latest init SpmManifestProbe --version 0.87.1 \
  --install-pods false --skip-git-init true
```

- [ ] **Step 2: Copiar la librería y quitarle el Swift**

El objetivo es que el scaffolder acepte el paquete. Se le saca el `.swift` y se deja solo el par
`.h`/`.mm`, que es exactamente el caso que sí sabe scaffoldear.

```bash
cd "$SCRATCH"
cp -R /Users/edavis/git/react-native-khipu rn-khipu-noswift
cd rn-khipu-noswift
rm -rf node_modules example lib .git ios/Khipu.swift ios/Khipu-Bridging-Header.h
# El podspec debe dejar de barrer .swift o el scaffolder vuelve a rechazarlo
sed -i '' 's/ios\/\*\*\/\*\.{h,m,mm,swift}/ios\/**\/*.{h,m,mm}/' react-native-khipu.podspec
```

- [ ] **Step 3: Instalar la librería en la app**

```bash
cd "$SCRATCH/SpmManifestProbe"
npm install --no-audit --no-fund
npm install --no-audit --no-fund "file:../rn-khipu-noswift"
```

- [ ] **Step 4: Correr el scaffolder**

```bash
cd "$SCRATCH/SpmManifestProbe/ios"
npx react-native spm scaffold
```

Esperado: escribe `node_modules/react-native-khipu/Package.swift`.

Si falla con *"can't be scaffolded automatically"*, quedó algún `.swift` o el `source_files` del
podspec sigue nombrándolo: revisar el Step 2.

- [ ] **Step 5: Leer el manifiesto generado y guardarlo como referencia**

```bash
cat "$SCRATCH/SpmManifestProbe/node_modules/react-native-khipu/Package.swift"
```

Copiar a `docs/superpowers/plans/spm-manifest-reference.md`, dentro de un bloque de código, y
anotar arriba: versión de RN (`0.87.1`), fecha, y el número de `AUTO-SCAFFOLDED-VERSION` que
aparezca en el archivo.

Extraer específicamente, porque es lo que Task 2 va a copiar literal:

- la línea `swift-tools-version`
- las líneas `.package(name: "ReactNative", path: "...")` y
  `.package(name: "React-GeneratedCode", path: "...")` **con sus rutas exactas**
- las líneas `.product(name: "ReactHeaders" | "ReactNativeHeaders" |
  "ReactNativeDependenciesHeaders", package: ...)` y `.product(name: "ReactAppHeaders", ...)`
- el valor de `publicHeadersPath`
- el `name` del package y el `name` del product

- [ ] **Step 6: Comprobar que el manifiesto generado efectivamente construye**

Vale poco copiar rutas de un archivo que nunca se probó:

```bash
cd "$SCRATCH/SpmManifestProbe/ios"
npx react-native spm
xcodebuild -project SpmManifestProbe.xcodeproj -scheme SpmManifestProbe \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' 2>&1 | tail -20
```

Esperado: `** BUILD SUCCEEDED **`. Sin Swift la librería no hace nada útil, pero compila y enlaza,
que es lo que se está midiendo.

Si **falla**, anotar el error en el archivo de referencia: significa que el camino SPM de RN no
está en pie ni para el caso simple, y el Plan 3 debería pausarse hasta que RN lo estabilice. Eso
es un resultado válido, no un fracaso.

- [ ] **Step 7: Limpiar y commitear la referencia**

```bash
rm -rf "$SCRATCH"
cd /Users/edavis/git/react-native-khipu
git add docs/superpowers/plans/spm-manifest-reference.md
git commit -m "docs: manifiesto SPM de referencia generado por el scaffolder de RN 0.87.1"
```

---

## Task 2: Escribir el `Package.swift` de dos targets

**Files:**
- Create: `Package.swift`
- Create: `ios/Sources/KhipuObjC/` (movimiento de `Khipu.h` y `Khipu.mm`)
- Create: `ios/Sources/Khipu/` (movimiento de `Khipu.swift`)
- Modify: `react-native-khipu.podspec` (`source_files` al layout nuevo)
- Modify: `package.json` (`files`)

**Interfaces:**
- Consumes: los valores literales del archivo de referencia de Task 1.
- Produces: `Package.swift` en la raíz del repo, con el product `react-native-khipu` sobre el
  target Swift `Khipu`, que depende del target Clang `KhipuObjC`.

- [ ] **Step 1: Mover las fuentes al layout que espera SPM**

SPM exige `Sources/<target>/`. Hoy los archivos están planos en `ios/`.

```bash
cd /Users/edavis/git/react-native-khipu
mkdir -p ios/Sources/KhipuObjC/include ios/Sources/Khipu
git mv ios/Khipu.mm ios/Sources/KhipuObjC/Khipu.mm
git mv ios/Khipu.h ios/Sources/KhipuObjC/include/Khipu.h
git mv ios/Khipu.swift ios/Sources/Khipu/Khipu.swift
git mv ios/Khipu-Bridging-Header.h ios/Sources/Khipu/Khipu-Bridging-Header.h
```

`include/` es donde SPM espera los headers públicos de un target Clang, y es lo que va a apuntar
`publicHeadersPath`.

- [ ] **Step 2: Ajustar el `source_files` del podspec**

El camino CocoaPods **no puede romperse**. En `react-native-khipu.podspec`:

```ruby
  s.source_files = "ios/Sources/**/*.{h,m,mm,swift}"
```

Y agregar, para que el header siga siendo visible como lo era cuando estaba plano:

```ruby
  s.header_mappings_dir = "ios/Sources/KhipuObjC/include"
```

- [ ] **Step 3: Verificar que CocoaPods sigue funcionando ANTES de escribir el manifiesto**

Este paso va antes a propósito: si el movimiento de archivos rompió el camino soportado, hay que
saberlo ahora y no después de haber escrito el manifiesto.

```bash
cd example/ios && pod install && cd ../..
yarn example ios
```

Un pago completo. Si falla, arreglar el podspec antes de seguir.

- [ ] **Step 4: Escribir el `Package.swift`**

Crear `Package.swift` en la raíz del repo. **Las líneas marcadas se copian del archivo de
referencia de Task 1**, no de acá — las rutas de abajo son ilustrativas y casi con seguridad no
son las correctas para tu versión de RN.

```swift
// swift-tools-version: 5.9
// EXPERIMENTAL: soporte SwiftPM para el camino `npx react-native spm`, que el
// propio React Native declara preview y no recomendado para produccion.
// CocoaPods sigue siendo el camino soportado de esta libreria.
//
// Las rutas relativas de abajo se resuelven desde el symlink `libs/<SwiftName>`
// que crea el autolinker de RN, no desde la ubicacion real de este paquete.
// Fueron obtenidas corriendo `npx react-native spm scaffold` contra RN 0.87.1
// (ver docs/superpowers/plans/spm-manifest-reference.md). Al subir de version de
// RN hay que regenerarlas y comparar: han cambiado varias veces.
import PackageDescription

let package = Package(
    name: "react-native-khipu",
    platforms: [.iOS("15.1")],
    products: [
        .library(name: "react-native-khipu", targets: ["Khipu"])
    ],
    dependencies: [
        // <<< COPIAR DE LA REFERENCIA (Task 1 Step 5) >>>
        .package(name: "ReactNative", path: "../../xcframeworks"),
        .package(name: "React-GeneratedCode", path: "../../codegen"),
        .package(url: "https://github.com/khipu/KhipuClientIOS.git", exact: "2.16.5"),
    ],
    targets: [
        .target(
            name: "KhipuObjC",
            dependencies: [
                // <<< COPIAR DE LA REFERENCIA (Task 1 Step 5) >>>
                .product(name: "ReactHeaders", package: "ReactNative"),
                .product(name: "ReactNativeHeaders", package: "ReactNative"),
                .product(name: "ReactNativeDependenciesHeaders", package: "ReactNative"),
                .product(name: "ReactAppHeaders", package: "React-GeneratedCode"),
            ],
            path: "ios/Sources/KhipuObjC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "Khipu",
            dependencies: [
                "KhipuObjC",
                .product(name: "KhipuClientIOS", package: "KhipuClientIOS"),
            ],
            path: "ios/Sources/Khipu"
        ),
    ]
)
```

- [ ] **Step 5: Comprobar que el manifiesto es sintácticamente válido**

```bash
swift package dump-package > /dev/null && echo "manifiesto OK"
```

Esperado: `manifiesto OK`. Este paso **no** valida las rutas relativas — solo que el archivo
compila como manifiesto. Las rutas se validan en Task 3.

- [ ] **Step 6: Incluir el manifiesto en el paquete publicado**

En `package.json`, agregar al array `files`:

```json
    "Package.swift",
```

Verificar:

```bash
npm pack --dry-run 2>&1 | grep -E "Package.swift|Sources/"
```

Esperado: `Package.swift` y los tres archivos bajo `ios/Sources/`.

- [ ] **Step 7: Commit**

```bash
git add Package.swift package.json react-native-khipu.podspec ios/
git commit -m "feat(ios): agregar Package.swift experimental para el camino SwiftPM de React Native"
```

---

## Task 3: Validar el camino SPM de punta a punta

**Files:** ninguno del repo — se valida contra una app desechable.

**Interfaces:**
- Consumes: el `Package.swift` de Task 2.
- Produces: la evidencia (o el hallazgo negativo) que decide si esto se libera.

- [ ] **Step 1: App RN 0.87.1 desechable con la librería por path**

```bash
SCRATCH=$(mktemp -d)
cd "$SCRATCH"
npx -y @react-native-community/cli@latest init SpmEndToEnd --version 0.87.1 \
  --install-pods false --skip-git-init true
cd SpmEndToEnd
npm install --no-audit --no-fund
npm install --no-audit --no-fund "file:/Users/edavis/git/react-native-khipu"
```

- [ ] **Step 2: Comprobar que el scaffolder NO se mete**

Es la comprobación de que RN reconoce nuestro manifiesto como *self-managed*:

```bash
cd "$SCRATCH/SpmEndToEnd/ios"
npx react-native spm
```

Esperado: **no** aparece `Package.swift is missing for library "react-native-khipu"`. Si aparece,
el manifiesto no está llegando al paquete: revisar el array `files` (Task 2 Step 6).

- [ ] **Step 3: Construir**

```bash
xcodebuild -project SpmEndToEnd.xcodeproj -scheme SpmEndToEnd \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' 2>&1 | tail -30
```

Esperado: `** BUILD SUCCEEDED **`.

Errores probables y qué significan:
- *"package ... doesn't exist"* → las rutas relativas de Task 2 Step 4 están mal; volver a la
  referencia de Task 1.
- *"no such module 'KhipuObjC'"* → `publicHeadersPath` no apunta a un directorio real con headers.
- *"target 'Khipu' ... outside the package root"* → algún `path:` quedó apuntando fuera de la raíz.

- [ ] **Step 4: Pago real por el camino SPM**

Reemplazar el `App.tsx` de la app desechable por uno que llame `startOperation`, y correr un pago
completo. Build normal, **nunca `--no-codesign`**.

Verificar lo mismo que en el camino CocoaPods: fuentes PublicSans, logo de Khipu, colores, y que
el resource bundle esté dentro del `.app`:

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData/SpmEndToEnd-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "SpmEndToEnd.app" | head -1)
ls "$APP" | grep -i bundle
```

Esperado: `KhipuClientIOS_KhipuClientIOS.bundle`.

> Este es el punto de mayor incertidumbre de los tres planes. En el camino CocoaPods el bundle sí
> se embebe — está medido. Por el camino SwiftPM puro **no se ha medido nunca**. Si el bundle no
> aparece, la UI de pago va a compilar y después romperse en runtime sin fuentes ni imágenes.

- [ ] **Step 5: Limpiar**

```bash
rm -rf "$SCRATCH"
```

- [ ] **Step 6: Decidir si se libera**

Con la evidencia en mano:

- **Si el Step 3 y el Step 4 pasaron** → seguir a Task 4.
- **Si el Step 3 falló** → no liberar. Revertir el `Package.swift` (dejando el movimiento de
  fuentes de Task 2 Step 1, que es una mejora en sí misma y ya quedó validada contra CocoaPods en
  Task 2 Step 3), y anotar el error en el spec §6 como hallazgo. Reintentar cuando RN estabilice.
- **Si compila pero el pago se rompe en runtime** → **no liberar**. Un `Package.swift` que compila
  y produce una UI rota es peor que no tener ninguno: el comercio pierde el tiempo depurando algo
  que nosotros ya sabíamos.

---

## Task 4: Documentar y liberar

**Files:**
- Modify: `README.md`
- Modify: `package.json` (versión, vía `release-it`)

**Interfaces:**
- Consumes: la evidencia de Task 3.
- Produces: la versión publicada.

- [ ] **Step 1: Agregar la sección al README**

Después de la sección iOS que dejó el Plan 1:

````markdown
### Swift Package Manager (experimental)

Si tu app usa `npx react-native spm` en vez de CocoaPods, esta librería trae un `Package.swift`
y no necesitas hacer nada especial.

**Es soporte experimental.** El propio React Native describe su integración con SwiftPM como
preview y no recomendada para producción todavía: los comandos y el layout generado pueden
cambiar entre versiones. Si tu app va a producción, usa CocoaPods, que es el camino que
soportamos.

Si actualizas React Native y el build por SwiftPM se rompe, [ábrenos un
issue](https://github.com/khipu/react-native-khipu/issues) — probablemente el contrato de RN
cambió y hay que regenerar el manifiesto.
````

- [ ] **Step 2: Verificación completa de que CocoaPods no se movió**

Lo más importante de este plan es no romper el camino que sí se soporta:

```bash
cd /Users/edavis/git/react-native-khipu
yarn lint && yarn typecheck && yarn test && yarn prepare
cd example/ios && pod install && cd ../..
yarn example ios
yarn example android
```

Un pago completo en cada plataforma.

- [ ] **Step 3: Liberar**

```bash
yarn release
```

**Minor.** El CHANGELOG debe decir que el soporte SwiftPM es experimental y que CocoaPods sigue
siendo el camino soportado, con la misma claridad que el README.

---

## Notas de ejecución

**Este plan puede terminar sin liberar nada, y eso está bien.** Task 3 Step 6 tiene tres salidas y
dos de ellas son "no liberar". El valor del plan está tanto en el manifiesto como en la medición:
hoy nadie sabe si el camino SwiftPM de RN funciona con una librería real que trae un SDK de
terceros con recursos. Después de Task 3 lo vamos a saber, se libere o no.

**El movimiento de fuentes de Task 2 Step 1 sobrevive aunque el resto se revierta.** Queda
validado contra CocoaPods en el Step 3 de esa misma tarea, y deja el repo listo para reintentar
cuando RN estabilice.

**Al subir de versión de React Native, regenerar la referencia de Task 1 y comparar.** Si las
rutas o los productos cambiaron, el manifiesto commiteado quedó roto y no hay nada que avise —
RN no regenera un manifiesto *self-managed*.
