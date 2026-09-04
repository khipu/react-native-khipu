# Plan 1 — Presenter, RN 0.87 y SPM

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que `react-native-khipu` resuelva `KhipuClientIOS` desde git en vez del trunk de
CocoaPods, funcione en React Native 0.87.1, y deje de cerrarle el modal al comercio.

**Architecture:** El podspec detecta `spm_dependency` (RN ≥0.75) y resuelve el SDK por SPM; si no
existe el helper, cae al pod congelado. El example sube de 0.74.1 a 0.87.1. El presenter pasa a
buscar el controlador más alto vía `connectedScenes` en vez de presentar sobre el
`rootViewController` cerrando lo que haya arriba.

**Tech Stack:** React Native 0.87.1 · CocoaPods 1.16.2 · Swift 6.3 / Xcode 26 · SwiftPM ·
Kotlin/Gradle (solo se corre, no se modifica en este plan)

**Spec:** `docs/superpowers/specs/2026-09-04-spm-react-native-khipu-design.md`

**Alcance:** este es el primero de tres planes. **Fuera de este plan:** el TurboModule con codegen
(Plan 2, toca iOS y Android) y el `Package.swift` experimental (Plan 3). No declarar
`codegenConfig` acá — arrastra a Android y es el trabajo del Plan 2.

## Global Constraints

- **Fecha dura:** el trunk de CocoaPods deja de aceptar podspecs el **2026-12-02**.
- **Piso de RN para SPM:** `spm_dependency` existe desde **RN 0.75**. Por debajo, rama `else`.
- **Versión del SDK:** `KhipuClientIOS` **2.16.5** en ambas ramas del podspec. Reconfirmar al
  momento del release que sigue siendo la última en trunk.
- **`min_ios_version_supported` en RN 0.87.1 = `15.1`.** No hardcodear pisos de iOS en el podspec;
  usar el helper.
- **Linking:** el camino estático debe funcionar. No introducir ningún requisito de
  `use_frameworks!`.
- **Nunca verificar runtime con `--no-codesign`** — deja al proceso sin Keychain, todo `SecItem*`
  devuelve `-34018`. Builds normales siempre.
- **El `presenter()` va privado al tipo del plugin**, nunca como extensión de `UIViewController`:
  enlazado estáticamente, un nombre público colisiona con el del comercio.
- **Las nueve URL schemes se copian desde la documentación de Khipu**, no desde otro example.
  Ojo con `bancochilemipass2` (no `bancochilemipass`) y `scotiabankgo` (no `keypass`).
- **Android no se modifica en este plan**, pero se corre para confirmar que no hay regresión.

---

## Task 1: Línea base antes de tocar nada

Medición irreversible: una vez que se toca el repo ya no se puede saber cómo se comportaba antes.

**Files:**
- Create: `docs/superpowers/plans/baseline-2026-09-04.md`

**Interfaces:**
- Consumes: nada.
- Produces: `docs/superpowers/plans/baseline-2026-09-04.md`, referenciado por las tareas 2, 3 y 6
  para distinguir "esto ya estaba roto" de "esto lo rompí yo".

- [ ] **Step 1: Confirmar que el árbol está limpio y en la rama correcta**

```bash
cd /Users/edavis/git/react-native-khipu
git status --short
git branch --show-current   # esperado: spm-migration
```

- [ ] **Step 2: Instalar y construir el example tal como está**

```bash
yarn install
cd example/ios && pod install && cd ../..
```

Esperado: `Pod installation complete!`, con `KhipuClientIOS (2.16.2)` en el output.

- [ ] **Step 3: Correr el example en iOS y anotar el comportamiento**

```bash
yarn example ios
```

Anotar, con un `operationId` de prueba real:
- ¿el pago abre y renderiza fuentes e imágenes?
- **cronometrar el retardo entre apretar Start y que aparezca la UI de Khipu** — se espera ≈1s
  por el `asyncAfter`. Este número es la prueba de que la tarea 2 sirvió.

- [ ] **Step 4: Correr el example en Android y anotar el comportamiento**

```bash
yarn example android
```

- [ ] **Step 5: Escribir el archivo de línea base**

Crear `docs/superpowers/plans/baseline-2026-09-04.md` con: versión de RN, versión de
`KhipuClientIOS` resuelta, el retardo cronometrado en iOS, si el pago completa en ambas
plataformas, y la salida de `yarn lint`, `yarn typecheck` y `yarn test`.

**No incluir el `operationId` en el archivo** — es un dato de operación, no va al repo.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/plans/baseline-2026-09-04.md
git commit -m "docs: línea base de comportamiento antes de la migración"
```

---

## Task 2: Arreglar el presenter y eliminar el delay

Bug vivo, independiente de todo lo demás, y se puede liberar solo. Se hace **antes** de subir el
example para que se pueda verificar contra el comportamiento medido en la tarea 1.

**Files:**
- Modify: `ios/Khipu.swift:105-116`
- Modify: `example/src/App.tsx` (harness de verificación)

**Interfaces:**
- Consumes: la medición del retardo de Task 1 Step 3.
- Produces: `Khipu.presenter() -> UIViewController?`, método estático privado del tipo `Khipu`.
  Ninguna otra tarea lo consume; queda interno.

- [ ] **Step 1: Escribir el harness que demuestra el bug**

En `example/src/App.tsx`, agregar un modal propio y un botón que lance el pago **con el modal
arriba**. El modal debe dejar pasar los toques o no se puede apretar nada abajo; por eso el botón
va dentro del modal.

```tsx
const [showModal, setShowModal] = React.useState(false);

const startBehindModal = () => {
  startOperation({ operationId: id, options: { title: 'Harness' } as KhipuOptions })
    .then(setResult)
    .catch((e) => console.log('HARNESS reject:', String(e)));
};

// dentro del render:
<Button title="Abrir modal propio" onPress={() => setShowModal(true)} />
<Modal visible={showModal} animationType="none" transparent={true}>
  <View style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.3)' }}>
    <Text>Modal del comercio. Debe seguir vivo despues del pago.</Text>
    <Button title="Lanzar pago con el modal arriba" onPress={startBehindModal} />
  </View>
</Modal>
```

- [ ] **Step 2: Correr el harness contra el código actual y comprobar que muerde**

```bash
yarn example ios
```

Apretar "Abrir modal propio", luego "Lanzar pago con el modal arriba". Anotar:

Esperado **con el código viejo** — y esto es lo que confirma que el harness sirve:
- el modal del comercio **desaparece** (lo cierra `dismiss(animated: false)`)
- pasa ≈1 segundo antes de que aparezca Khipu

Si el modal **no** desaparece o no hay retardo, el harness no está ejercitando el camino y hay que
arreglarlo antes de seguir. Un harness que no muerde no prueba nada.

- [ ] **Step 3: Escribir el `presenter()`**

En `ios/Khipu.swift`, dentro de `class Khipu`, antes de `startOperation`:

```swift
    /// Devuelve el controlador mas alto de la escena activa.
    /// Privado a proposito: enlazado estaticamente, un nombre publico como
    /// `topMostViewController()` colisiona con el del comercio.
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

- [ ] **Step 4: Reemplazar el bloque del presenter, el dismiss y el delay**

En `ios/Khipu.swift`, reemplazar exactamente esto:

```swift
        DispatchQueue.main.async {
            guard let presenter = UIApplication.shared.windows.filter({$0.isKeyWindow}).first?.rootViewController else {
                reject("NO_OPERATION_ID", "No rootViewController found", NSError())
                return
            }


            presenter.presentedViewController?.dismiss(animated: false)


            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                guard let operationId = startOperationOptions["operationId"] else {
                    reject("NO_OPERATION_ID", "OperationId is needed to start the operation", NSError())
                    return
                }

                KhipuLauncher.launch(presenter: presenter,
```

por esto:

```swift
        DispatchQueue.main.async {
            guard let presenter = Khipu.presenter() else {
                reject("NO_PRESENTER", "No view controller available to present from", NSError())
                return
            }

            guard let operationId = startOperationOptions["operationId"] else {
                reject("NO_OPERATION_ID", "OperationId is needed to start the operation", NSError())
                return
            }

            KhipuLauncher.launch(presenter: presenter,
```

Ojo con la indentación: al sacar el `asyncAfter` desaparece un nivel de anidación. Todo el cuerpo
desde `KhipuLauncher.launch` hasta el cierre del closure sube cuatro espacios, y sobra una llave de
cierre al final del bloque.

Se corrige de paso el código de error: el guard del presenter devolvía `NO_OPERATION_ID`, que era
incorrecto y despistaba al depurar.

- [ ] **Step 5: Compilar**

```bash
cd example/ios && pod install && cd ../..
yarn example ios
```

Esperado: compila sin errores. Si aparece "unbalanced braces" o similar, revisar el Step 4 — es la
llave que sobra.

- [ ] **Step 6: Correr el harness y comprobar que el bug se fue**

Repetir el Step 2. Esperado ahora:
- el modal del comercio **sigue visible** detrás de Khipu
- Khipu aparece **sin el segundo de espera**, comparado contra el número de Task 1 Step 3
- en la consola de Xcode, **cero** ocurrencias de `already presenting` y de `Attempt to present`

- [ ] **Step 7: Verificar el camino normal, sin modal**

Lanzar un pago sin abrir el modal. Debe abrir igual que siempre, ahora sin el retardo.

- [ ] **Step 8: Correr el resto de la verificación**

```bash
yarn lint && yarn typecheck && yarn test
```

- [ ] **Step 9: Commit**

```bash
git add ios/Khipu.swift example/src/App.tsx
git commit -m "fix(ios): presentar sobre el controlador mas alto en vez de cerrar el modal del comercio"
```

- [ ] **Step 10: Liberar como patch**

Este arreglo no depende de nada de lo que sigue y corrige un bug que los comercios están sufriendo
hoy. Liberarlo solo, sin esperar la migración.

```bash
yarn release
```

Entrada de CHANGELOG: arreglo del presenter, se elimina el retardo de 1 segundo en cada pago, deja
de cerrarse el modal del comercio.

---

## Task 3: Subir el example a React Native 0.87.1

Trece minors. Se regenera el proyecto nativo en vez de parcharlo, y **el `Info.plist` se rehace
como parte de la regeneración**, no después: un plist parchado a posteriori se borra en silencio si
algo vuelve a regenerar.

**Files:**
- Modify: `example/package.json`
- Replace: `example/ios/` (regenerado)
- Replace: `example/android/` (regenerado)
- Modify: `example/ios/KhipuExample/Info.plist` (dentro de la regeneración)
- Modify: `package.json` (`devDependencies.react-native`, `@types/react`, `react`)

**Interfaces:**
- Consumes: la línea base de Task 1.
- Produces: un `example` en RN 0.87.1 con `Info.plist` conteniendo `LSApplicationQueriesSchemes`.
  Task 4 depende de que este example exista para poder probar `spm_dependency`.

- [ ] **Step 1: Anotar lo que hay que preservar del example actual**

Antes de regenerar, listar lo propio:

```bash
cd /Users/edavis/git/react-native-khipu
cat example/ios/KhipuExample/Info.plist
cat example/ios/Podfile
cat example/package.json
grep -rn "KhipuExample" example/ios/KhipuExample.xcodeproj/project.pbxproj | head
```

Lo que hay que reponer después: nombre del bundle `KhipuExample`, el esquema `KhipuExample`, el
script `build:ios` de `example/package.json`, y el `Podfile` con el `source` de CocoaPods.

- [ ] **Step 2: Generar un example limpio en 0.87.1 fuera del repo**

```bash
cd /tmp && rm -rf KhipuExampleNew
npx -y @react-native-community/cli@latest init KhipuExample --version 0.87.1 \
  --directory /tmp/KhipuExampleNew --install-pods false --skip-git-init true
```

- [ ] **Step 3: Reemplazar los proyectos nativos**

```bash
cd /Users/edavis/git/react-native-khipu
rm -rf example/ios example/android
cp -R /tmp/KhipuExampleNew/ios example/ios
cp -R /tmp/KhipuExampleNew/android example/android
```

- [ ] **Step 4: Reponer el `Podfile`**

`example/ios/Podfile` — al `Podfile` generado agregarle arriba el `source`, y dejar el `target`
apuntando a `KhipuExample`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
```

- [ ] **Step 5: Agregar las nueve URL schemes al `Info.plist`**

En `example/ios/KhipuExample/Info.plist`, antes del `</dict>` final:

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

Verificado contra la documentación de Khipu: las páginas de iOS, Flutter, Capacitor, Cordova y
React Native coinciden en esta lista y este orden.

- [ ] **Step 6: Verificar que el plist quedó bien formado**

```bash
plutil -lint example/ios/KhipuExample/Info.plist
/usr/libexec/PlistBuddy -c "Print :LSApplicationQueriesSchemes" example/ios/KhipuExample/Info.plist
```

Esperado: `OK`, y las nueve schemes listadas en orden.

- [ ] **Step 7: Subir las dependencias JS**

En `example/package.json`: `react-native` a `0.87.1` y `react` a la versión que pida 0.87.1
(leerla de `/tmp/KhipuExampleNew/package.json`, no adivinarla). Reponer el script `build:ios`.

En el `package.json` raíz: `devDependencies.react-native` a `0.87.1`, y `react` / `@types/react`
alineados con el example.

**No tocar `react-native-builder-bob`** — sigue en `0.20.0`. Subirlo cambia el formato de salida
JS y es un trabajo aparte.

- [ ] **Step 8: Reinstalar y construir**

```bash
yarn install
cd example/ios && pod install && cd ../..
yarn example ios
```

- [ ] **Step 9: Verificar contra la línea base**

Un pago completo en iOS, con fuentes e imágenes. Y **repetir el harness de Task 2** — el modal del
comercio debe seguir sobreviviendo tras el salto de versión.

- [ ] **Step 10: Verificar Android**

```bash
yarn example android
```

Android no se modificó en este plan; si algo se rompió acá es por el salto de RN, y la línea base
de Task 1 dice cómo se comportaba antes.

- [ ] **Step 11: Commit**

```bash
git add example package.json yarn.lock
git commit -m "chore(example): subir a React Native 0.87.1 y declarar las URL schemes bancarias"
```

---

## Task 4: `spm_dependency` en el podspec y helper del Podfile

El corazón del plan. Sin esto, después del 2 de diciembre no hay forma de entregar versiones
nuevas del SDK.

**Files:**
- Modify: `react-native-khipu.podspec`
- Create: `ios/khipu_spm_fix.rb`
- Modify: `example/ios/Podfile`
- Modify: `package.json` (campo `files`)

**Interfaces:**
- Consumes: el example en 0.87.1 de Task 3.
- Produces: `khipu_fix_spm_modulemaps(installer)`, función Ruby global definida en
  `ios/khipu_spm_fix.rb`. Task 5 la documenta en el README; Task 6 la libera.

- [ ] **Step 1: Escribir el helper del Podfile**

Crear `ios/khipu_spm_fix.rb`:

```ruby
# Rodea un bug de React Native (verificado en 0.87.1).
#
# scripts/cocoapods/spm.rb aplana el build dir de un pod que consume paquetes SPM
# con linking estatico, y despues reescribe la referencia al modulemap en los
# xcconfig agregados con:
#
#   gsub("${PODS_CONFIGURATION_BUILD_DIR}/#{pod_name}/#{pod_name}.modulemap", ...)
#
# Pero CocoaPods nombra el modulemap con el MODULE name (react_native_khipu) y el
# directorio con el POD name (react-native-khipu). El gsub nunca calza y la
# reescritura queda en un no-op silencioso, asi que el build falla con
# "module map file ... not found".
#
# Afecta a cualquier pod con guion en el nombre, o sea a casi toda libreria de la
# comunidad. Retirar esta funcion cuando el fix este upstream y el piso de RN lo
# permita.
def khipu_fix_spm_modulemaps(installer)
  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.xcconfigs.each do |config_name, config_file|
      %w[OTHER_CFLAGS OTHER_SWIFT_FLAGS].each do |key|
        value = config_file.attributes[key]
        next unless value

        updated = installer.pod_targets.reduce(value) do |acc, pod_target|
          acc.gsub(
            "${PODS_CONFIGURATION_BUILD_DIR}/#{pod_target.name}/#{pod_target.product_module_name}.modulemap",
            "${PODS_CONFIGURATION_BUILD_DIR}/#{pod_target.product_module_name}.modulemap"
          )
        end

        config_file.attributes[key] = updated if updated != value
      end

      config_file.save_as(aggregate_target.xcconfig_path(config_name))
    end
  end
end
```

- [ ] **Step 2: Incluir el helper en el paquete publicado**

En `package.json`, el array `files` ya incluye `"ios"`, así que `ios/khipu_spm_fix.rb` viaja solo.
Confirmarlo:

```bash
npm pack --dry-run 2>&1 | grep khipu_spm_fix
```

Esperado: la ruta aparece listada. Si no, agregar `"ios/khipu_spm_fix.rb"` a `files`.

- [ ] **Step 3: Reescribir el podspec**

Reemplazar el contenido completo de `react-native-khipu.podspec`:

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

  # RN >=0.75 resuelve el SDK desde git y queda inmune al freeze del trunk de
  # CocoaPods del 2026-12-02. RN <0.75 cae al pod, congelado en la ultima version
  # publicada en trunk antes de esa fecha.
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

Desaparece la rama manual de New Architecture (`folly_compiler_flags`, `React-Codegen`,
`RCT-Folly`, `RCTRequired`, `RCTTypeSafety`, `ReactCommon/turbomodule/core`).
`install_modules_dependencies` la cubre desde RN 0.71 y es lo que hace el template actual.

- [ ] **Step 4: Cablear el helper en el `Podfile` del example**

En `example/ios/Podfile`, arriba:

```ruby
require File.join(
  File.dirname(`node --print "require.resolve('react-native-khipu/package.json')"`),
  "ios/khipu_spm_fix.rb"
)
```

y dentro del `post_install`, **después** de `react_native_post_install`:

```ruby
    khipu_fix_spm_modulemaps(installer)
```

El orden importa: `react_native_post_install` es quien corre la reescritura rota de RN, así que
la corrección tiene que ir después.

- [ ] **Step 5: Instalar y comprobar que SPM entró**

```bash
cd example/ios && pod install
```

Esperado en el output:

```
[SPM] Adding product dependency KhipuClientIOS to react-native-khipu
[SPM] Building react-native-khipu into the shared products dir to avoid duplicate module maps
```

y el warning de linking estático, que es esperado y no es un problema.

- [ ] **Step 6: Comprobar que el helper corrigió el path**

```bash
grep -o '\-fmodule-map-file=[^ ]*khipu[^ ]*' \
  "Pods/Target Support Files/Pods-KhipuExample/Pods-KhipuExample.debug.xcconfig" | sort -u
```

Esperado: `${PODS_CONFIGURATION_BUILD_DIR}/react_native_khipu.modulemap`

Si sale `${PODS_CONFIGURATION_BUILD_DIR}/react-native-khipu/react_native_khipu.modulemap`, el
helper no corrió: revisar el orden dentro del `post_install`.

- [ ] **Step 7: Construir con linking estático**

```bash
cd /Users/edavis/git/react-native-khipu/example/ios
xcodebuild -workspace KhipuExample.xcworkspace -scheme KhipuExample \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  COMPILER_INDEX_STORE_ENABLE=NO 2>&1 | tail -20
```

Esperado: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Comprobar que el árbol salió de git y no del trunk**

```bash
ls ~/Library/Developer/Xcode/DerivedData/KhipuExample-*/SourcePackages/checkouts
```

Esperado, los seis: `KhipuClientIOS`, `KhenshinProtocolSwift`, `KhenshinSecureMessage`,
`Starscream`, `socket.io-client-swift`, `tweetnacl-swiftwrap`.

Y que `KhipuClientIOS` **ya no** aparezca como pod:

```bash
grep -c "KhipuClientIOS" Podfile.lock
```

Esperado: `0`.

- [ ] **Step 9: Comprobar que el resource bundle se embebe**

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData/KhipuExample-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "KhipuExample.app" | head -1)
ls "$APP/KhipuClientIOS_KhipuClientIOS.bundle"
```

Esperado: `Assets.car`, `khipuClient.html`, las cuatro `PublicSans-*.ttf`, `authorize.png`,
`logo-khipu-color.png`.

- [ ] **Step 10: Pago real bajo SPM**

```bash
cd /Users/edavis/git/react-native-khipu && yarn example ios
```

Build normal, **nunca `--no-codesign`**. Verificar: fuentes PublicSans, logo de Khipu en "Operado
por", colores del tema, y `v2.16.5` al pie — esa versión es la prueba de que resolvió por SPM.

- [ ] **Step 11: Probar el linking dinámico**

Es el único punto del spec que no se sondeó.

```bash
cd example/ios && USE_FRAMEWORKS=dynamic pod install && cd ../..
yarn example ios
```

Si funciona, anotarlo. Si falla, **documentar el error exacto** y volver a estático — es un
hallazgo nuevo que va al README, no algo que bloquee el plan.

```bash
cd example/ios && unset USE_FRAMEWORKS && pod install && cd ../..
```

- [ ] **Step 12: Verificar la rama `else` del podspec**

La rama de fallback es lo único que van a recibir los comercios en RN <0.75, y si está rota nadie
se va a enterar hasta que sea tarde. Forzarla sin instalar un RN viejo, simulando que el helper no
existe:

```bash
cd /Users/edavis/git/react-native-khipu
ruby -e '
  # Sin spm_dependency definido, respond_to?(:spm_dependency, true) es false
  # y el podspec debe caer a s.dependency sin explotar.
  def min_ios_version_supported; "15.1"; end
  def install_modules_dependencies(s); end
  require "cocoapods"
  spec = Pod::Specification.from_file("react-native-khipu.podspec")
  dep = spec.dependencies.find { |d| d.name == "KhipuClientIOS" }
  abort "FALLO: la rama else no declaro KhipuClientIOS" unless dep
  puts "OK rama else -> #{dep.name} #{dep.requirement}"
'
```

Esperado: `OK rama else -> KhipuClientIOS = 2.16.5`

Si aborta, la rama `else` está rota y hay que arreglarla antes de seguir.

- [ ] **Step 13: `pod lib lint`**

```bash
pod lib lint react-native-khipu.podspec --configuration=Debug --skip-tests --allow-warnings
```

- [ ] **Step 14: Commit**

```bash
git add react-native-khipu.podspec ios/khipu_spm_fix.rb example/ios/Podfile example/ios/Podfile.lock package.json
git commit -m "feat(ios): resolver KhipuClientIOS por SPM en vez del trunk de CocoaPods"
```

---

## Task 5: README y CI

**Files:**
- Modify: `README.md:61-70` (sección `## iOS`)
- Modify: `.github/workflows/ci.yml` (job `build-ios`)
- Modify: `turbo.json`

**Interfaces:**
- Consumes: `khipu_fix_spm_modulemaps` de Task 4.
- Produces: nada que otra tarea consuma.

- [ ] **Step 1: Reescribir la sección iOS del README**

Reemplazar la sección `## iOS` completa (hoy solo dice `pod install --repo-update`) por:

````markdown
## iOS

### 1. Configura el Podfile

Desde la versión 2.15.0 el SDK de iOS se resuelve con Swift Package Manager en vez de
CocoaPods, porque el trunk de CocoaPods dejó de aceptar versiones nuevas. Agrega esto a tu
`ios/Podfile`, arriba del todo:

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

Este helper rodea un bug de React Native (presente en 0.87.1) que impide construir cualquier
pod cuyo nombre lleve guión cuando consume paquetes SPM. Lo vamos a retirar cuando el arreglo
esté en React Native.

**No necesitas `use_frameworks!`.** El linking estático, que es el default, funciona.

### 2. Instala

```sh
cd ios
pod install
cd ..
```

### 3. Declara las apps bancarias

Para que Khipu pueda abrir la app del banco, tu `ios/<TuApp>/Info.plist` debe declarar estos
URL schemes. **Esto va en tu app**, no basta con que estén en nuestro ejemplo:

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

### Si usas React Native anterior a 0.75

`spm_dependency` no existe antes de 0.75, así que el plugin cae automáticamente a CocoaPods y
no necesitas el helper del paso 1. La contrapartida es que el SDK queda fijo en
`KhipuClientIOS 2.16.5`: para recibir versiones nuevas hay que actualizar React Native.
````

- [ ] **Step 2: Ampliar los inputs de turbo para iOS**

En `turbo.json`, dentro de `build:ios`, la lista `inputs` no considera el helper nuevo. Agregar:

```json
        "ios/khipu_spm_fix.rb",
```

- [ ] **Step 3: Ajustar la caché de pods del CI**

En `.github/workflows/ci.yml`, el paso que cachea pods usa
`hashFiles('example/ios/Podfile.lock')`. Con SPM el `Podfile.lock` ya no menciona
`KhipuClientIOS`, así que esa clave no distingue un cambio de versión del SDK. Cambiar la clave
para que incluya el podspec, que es donde vive ahora el pin:

```yaml
          key: ${{ runner.os }}-cocoapods-${{ hashFiles('example/ios/Podfile.lock', 'react-native-khipu.podspec') }}
```

- [ ] **Step 4: Correr el CI localmente hasta donde se pueda**

```bash
yarn lint && yarn typecheck && yarn test && yarn prepare
```

- [ ] **Step 5: Commit**

```bash
git add README.md .github/workflows/ci.yml turbo.json
git commit -m "docs: documentar la instalacion iOS con SPM y las URL schemes bancarias"
```

- [ ] **Step 6: Empujar la rama y confirmar que el CI pasa**

```bash
git push -u origin spm-migration
```

Esperar el job `build-ios`. Si falla por el helper, es porque el `Podfile` del example no lo tiene
cableado: revisar Task 4 Step 4.

---

## Task 6: Release

**Files:**
- Modify: `package.json` (versión, vía `release-it`)
- Modify: `CHANGELOG.md` (generado)

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: la versión publicada en npm.

- [ ] **Step 1: Reconfirmar la versión de `KhipuClientIOS` en trunk**

Es el piso permanente para RN <0.75, así que hay que mirarlo justo antes de liberar, no asumirlo:

```bash
curl -sL "https://trunk.cocoapods.org/api/v1/pods/KhipuClientIOS" | \
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
    const vs=JSON.parse(s).versions.map(v=>v.name);
    const k=a=>a.split(".").map(Number);
    console.log(vs.sort((a,b)=>{const x=k(a),y=k(b);for(let i=0;i<3;i++){if((x[i]||0)!==(y[i]||0))return (x[i]||0)-(y[i]||0)}return 0}).pop());
  })'
```

Si devuelve algo mayor que `2.16.5`, actualizar **las dos** ramas del podspec y volver a correr
Task 4 Steps 5-10.

- [ ] **Step 2: Verificación final completa**

```bash
yarn lint && yarn typecheck && yarn test && yarn prepare
cd example/ios && pod install && cd ../..
yarn example ios
yarn example android
```

Un pago completo en cada plataforma, más el harness del modal en iOS.

- [ ] **Step 3: `openApp` en dispositivo físico**

Único paso del plan que **no se puede hacer en simulador**: las apps bancarias no existen ahí, así
que `canOpenURL` siempre falla y no prueba nada.

En un iPhone real con al menos una app bancaria instalada, correr el example en modo release y
llevar un pago hasta el punto donde Khipu ofrece abrir la app del banco. Confirmar que **abre**.

```bash
cd example/ios
xcodebuild -workspace KhipuExample.xcworkspace -scheme KhipuExample \
  -configuration Release -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates
```

Nunca con `--no-codesign`: sin `application-identifier` en los entitlements el proceso queda sin
Keychain y el pago muere por una razón que no tiene nada que ver con lo que se está midiendo.

**Si no hay hardware disponible, no darlo por bueno.** Anotar en el CHANGELOG y en el archivo de
línea base que `openApp` quedó verificado solo por inspección contra la documentación. Según la
sesión de `flutter_khipu`, nadie lo ha ejercitado en runtime en ninguna de las cuatro
integraciones de Khipu, así que una corrida acá sería la primera — y decir que se verificó sin
haberlo hecho arruina ese dato para todos.

- [ ] **Step 4: Liberar**

```bash
yarn release
```

Es un **minor** (`2.15.0`): cambia cómo se resuelve la dependencia y agrega un paso de instalación
obligatorio en RN ≥0.75. El CHANGELOG debe decir explícitamente que el `Podfile` necesita el
helper, o los comercios van a actualizar y romperse sin entender por qué.

- [ ] **Step 5: Abrir el PR upstream a React Native**

El bug del `gsub` afecta a toda librería con guión en el nombre. Corregir
`rewrite_aggregate_modulemap_references` en `packages/react-native/scripts/cocoapods/spm.rb` para
que use `product_module_name` en el nombre del archivo, con la evidencia de Task 4 Step 6.

Anotar el número del PR en el README junto al helper, para saber cuándo se puede retirar.

---

## Notas de ejecución

**Si Task 3 se complica**, es la más frágil: trece minors de salto y el proyecto nativo se
reemplaza entero. La línea base de Task 1 es lo que permite distinguir "esto lo rompió el salto de
RN" de "esto lo rompí yo". Si algo del example queda roto y no es del camino de pago, anotarlo y
seguir: el objetivo del plan es la resolución de dependencias, no un example perfecto.

**Task 2 se puede liberar sin el resto.** Si la fecha aprieta y el salto a 0.87 se complica, el
arreglo del presenter ya está en manos de los comercios.

**El `operationId` de pruebas no va a ningún archivo del repo**, ni al plan, ni al CHANGELOG, ni a
la línea base.
