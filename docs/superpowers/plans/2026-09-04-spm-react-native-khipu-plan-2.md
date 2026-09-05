# Plan 2 — TurboModule con codegen en iOS y Android

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir `react-native-khipu` en un TurboModule con codegen en las dos plataformas,
sin cambiar la API pública de JavaScript.

**Architecture:** Un spec de codegen en `src/NativeKhipu.ts` genera, en iOS, un protocolo
`NativeKhipuSpec` y structs tipados que el `.mm` consume y delega a la clase Swift; en Android,
una clase abstracta `NativeKhipuSpec` que `KhipuModule` pasa a extender. `src/index.tsx` mantiene
las firmas actuales para que ningún comercio tenga que tocar su código.

**Tech Stack:** React Native 0.87.1 · `@react-native/codegen` · Swift 6.3 / ObjC++ · Kotlin

**Spec:** `docs/superpowers/specs/2026-09-04-spm-react-native-khipu-design.md`

**Depende de:** Plan 1 completo y liberado. Este plan asume el example ya en RN 0.87.1 y el
podspec ya con `spm_dependency`.

## Global Constraints

- **La API pública de JS no cambia.** `startOperation(options)` conserva su firma y la forma del
  objeto que resuelve. Cualquier ajuste de tipos es de declaración, no de forma.
- **`codegenConfig` es cross-platform.** Declararlo obliga a migrar iOS y Android en el mismo
  cambio. No se libera a medias.
- **Codegen protege el contrato de claves solo en iOS.** Medido: el Java generado es
  `public abstract void startOperation(ReadableMap options, Promise promise)` y **no contiene
  ninguna clave de opciones**. Android las sigue leyendo por string. Por eso el test de conjuntos
  de claves (Task 1) es permanente, no una red temporal.
- **Los tipos ya están verificados.** Se corrió el parser y los cuatro generadores de RN 0.87.1
  sobre el spec candidato: pasan la unión de literales, los objetos anidados, el array y los
  opcionales. No hay que rediseñar tipos.
- **El nombre del módulo es `Khipu`**, y debe seguir siéndolo en las dos plataformas: es lo que
  `TurboModuleRegistry` busca y lo que `KhipuModule.NAME` ya declara.
- **Nunca verificar runtime con `--no-codesign`.**

---

## Task 1: Test de contrato de claves entre las tres superficies

Va **primero**, antes de tocar nada, por dos razones: es la red durante la migración, y es la
única defensa permanente del lado Android, donde codegen no protege nada.

**Files:**
- Create: `src/__tests__/key-contract.test.ts`

**Interfaces:**
- Consumes: nada.
- Produces: el test suite `key-contract`. Las tareas 2 a 5 lo corren como verificación.

- [ ] **Step 1: Escribir el test**

Crear `src/__tests__/key-contract.test.ts`:

```ts
import { readFileSync } from 'fs';
import { join } from 'path';

const root = join(__dirname, '..', '..');
const read = (p: string) => readFileSync(join(root, p), 'utf8');

/** Claves declaradas en el spec de codegen, por bloque de tipo. */
function tsKeys(typeName: string): Set<string> {
  const src = read('src/NativeKhipu.ts');
  const block = new RegExp(`export type ${typeName} = \\{([\\s\\S]*?)\\n\\};`).exec(src);
  if (!block) throw new Error(`No se encontro el tipo ${typeName} en src/NativeKhipu.ts`);
  return new Set([...block[1].matchAll(/^\s{2}(\w+)\??:/gm)].map((m) => m[1]));
}

/** Claves que Swift lee del NSDictionary entrante. */
function swiftReadKeys(): Set<string> {
  const src = read('ios/Khipu.swift');
  return new Set([...src.matchAll(/\["(\w+)"\]/g)].map((m) => m[1]));
}

/** Claves que Kotlin lee del ReadableMap entrante. */
function kotlinReadKeys(): Set<string> {
  const src = read('android/src/main/java/com/khipu/KhipuModule.kt');
  return new Set(
    [...src.matchAll(/\.(?:getString|getBoolean|getMap|hasKey)\("(\w+)"\)/g)].map((m) => m[1])
  );
}

/** Claves que Kotlin escribe en el mapa de vuelta. */
function kotlinWriteKeys(): Set<string> {
  const src = read('android/src/main/java/com/khipu/KhipuModule.kt');
  return new Set([...src.matchAll(/\.put(?:String|Array|Map)\("(\w+)"/g)].map((m) => m[1]));
}

/** Claves que Swift escribe en el diccionario de vuelta. */
function swiftWriteKeys(): Set<string> {
  const src = read('ios/Khipu.swift');
  return new Set([...src.matchAll(/^\s*"(\w+)":/gm)].map((m) => m[1]));
}

const missing = (a: Set<string>, b: Set<string>) => [...a].filter((k) => !b.has(k)).sort();

describe('el extractor sigue mordiendo', () => {
  // Sin estos, un reformateo que rompa un patron colapsa los conjuntos a vacio
  // y todas las comparaciones de abajo pasan trivialmente. Un extractor roto se
  // ve identico a un contrato sano, que es el peor modo de falla posible.
  it('encuentra los tipos del spec de codegen', () => {
    expect(tsKeys('KhipuOptions').size).toBeGreaterThanOrEqual(10);
    expect(tsKeys('KhipuColors').size).toBe(12);
    expect(tsKeys('KhipuResult').size).toBeGreaterThanOrEqual(7);
    expect(tsKeys('KhipuEvent').size).toBe(3);
  });

  it('encuentra claves leidas en Swift', () => {
    expect(swiftReadKeys().size).toBeGreaterThanOrEqual(20);
  });

  it('encuentra claves escritas en Swift', () => {
    expect(swiftWriteKeys().size).toBeGreaterThanOrEqual(7);
  });

  it('encuentra claves leidas en Kotlin', () => {
    expect(kotlinReadKeys().size).toBeGreaterThanOrEqual(20);
  });

  it('encuentra claves escritas en Kotlin', () => {
    expect(kotlinWriteKeys().size).toBeGreaterThanOrEqual(7);
  });
});

describe('contrato de entrada: JS -> nativo', () => {
  const declared = new Set([...tsKeys('KhipuOptions'), ...tsKeys('KhipuColors')]);

  it('Swift no lee ninguna clave que el spec no declare', () => {
    const read = swiftReadKeys();
    read.delete('operationId');
    read.delete('options');
    expect(missing(read, declared)).toEqual([]);
  });

  it('Kotlin no lee ninguna clave que el spec no declare', () => {
    const read = kotlinReadKeys();
    read.delete('operationId');
    read.delete('options');
    expect(missing(read, declared)).toEqual([]);
  });

  it('las dos plataformas leen exactamente el mismo conjunto', () => {
    expect(missing(swiftReadKeys(), kotlinReadKeys())).toEqual([]);
    expect(missing(kotlinReadKeys(), swiftReadKeys())).toEqual([]);
  });
});

describe('contrato de salida: nativo -> JS', () => {
  const declared = new Set([...tsKeys('KhipuResult'), ...tsKeys('KhipuEvent')]);

  it('Swift no escribe ninguna clave que el spec no declare', () => {
    expect(missing(swiftWriteKeys(), declared)).toEqual([]);
  });

  it('Kotlin no escribe ninguna clave que el spec no declare', () => {
    expect(missing(kotlinWriteKeys(), declared)).toEqual([]);
  });

  it('el spec no declara nada que ninguna plataforma entregue', () => {
    const written = new Set([...swiftWriteKeys(), ...kotlinWriteKeys()]);
    expect(missing(declared, written)).toEqual([]);
  });
});
```

- [ ] **Step 2: Comprobar que falla porque el spec todavía no existe**

```bash
yarn test key-contract
```

Esperado: FALLA con `No se encontro el tipo KhipuOptions en src/NativeKhipu.ts`, o `ENOENT` sobre
ese archivo. Es correcto — el spec lo crea la Task 2.

- [ ] **Step 3: Comprobar que los extractores de Swift y Kotlin ya muerden hoy**

Los dos archivos nativos ya existen, así que sus extractores se pueden validar antes del spec:

```bash
yarn test key-contract -t "encuentra claves"
```

Esperado: pasan los cuatro tests de Swift y Kotlin. Si alguno falla por conteo, el patrón no está
calzando con el código real y hay que arreglarlo **ahora**, no después.

- [ ] **Step 4: Demostrar que el test muerde, renombrando una clave a propósito**

```bash
sed -i '' 's/options\["titleImageUrl"\]/options["titleImageUrlXX"]/g' ios/Khipu.swift
yarn test key-contract
```

Esperado: FALLA en *"Swift no lee ninguna clave que el spec no declare"* o en la comparación entre
plataformas, nombrando `titleImageUrlXX`. Si **pasa**, el test no sirve y hay que arreglarlo.

Revertir:

```bash
git checkout ios/Khipu.swift
```

- [ ] **Step 5: Commit**

```bash
git add src/__tests__/key-contract.test.ts
git commit -m "test: verificar el contrato de claves entre JS, Swift y Kotlin"
```

---

## Task 2: El spec de codegen

**Files:**
- Create: `src/NativeKhipu.ts`
- Modify: `src/index.tsx`
- Modify: `package.json` (bloque `codegenConfig`)

**Interfaces:**
- Consumes: el test de Task 1.
- Produces:
  - `src/NativeKhipu.ts` exportando los tipos `KhipuColors`, `KhipuOptions`,
    `StartOperationOptions`, `KhipuEvent`, `KhipuResult` y `Spec`, con default export del módulo.
  - En iOS, el protocolo generado `NativeKhipuSpec` y el struct
    `JS::NativeKhipu::StartOperationOptions` que consume Task 3.
  - En Android, la clase abstracta `NativeKhipuSpec` con
    `public abstract void startOperation(ReadableMap options, Promise promise)` que consume
    Task 4.

- [ ] **Step 1: Escribir el spec**

Crear `src/NativeKhipu.ts`. Estos tipos ya fueron verificados contra el parser y los cuatro
generadores de RN 0.87.1 — no modificarlos sin volver a correr Task 2 Step 3.

```ts
import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export type KhipuColors = {
  lightBackground?: string;
  lightOnBackground?: string;
  lightPrimary?: string;
  lightOnPrimary?: string;
  lightTopBarContainer?: string;
  lightOnTopBarContainer?: string;
  darkBackground?: string;
  darkOnBackground?: string;
  darkPrimary?: string;
  darkOnPrimary?: string;
  darkTopBarContainer?: string;
  darkOnTopBarContainer?: string;
};

export type KhipuOptions = {
  locale?: string;
  title?: string;
  titleImageUrl?: string;
  skipExitPage?: boolean;
  skipExitSuccessPage?: boolean;
  showFooter?: boolean;
  showMerchantLogo?: boolean;
  showPaymentDetails?: boolean;
  theme?: 'light' | 'dark' | 'system';
  colors?: KhipuColors;
};

export type StartOperationOptions = {
  operationId: string;
  options?: KhipuOptions;
};

export type KhipuEvent = {
  name: string;
  type: string;
  timestamp: string;
};

export type KhipuResult = {
  operationId: string;
  exitTitle: string;
  exitMessage: string;
  exitUrl?: string;
  result: string;
  failureReason?: string;
  continueUrl?: string;
  events: Array<KhipuEvent>;
};

export interface Spec extends TurboModule {
  startOperation(options: StartOperationOptions): Promise<KhipuResult>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('Khipu');
```

Dos cambios de declaración respecto de `src/index.tsx` de hoy, ninguno cambia la forma del objeto:

- Los campos opcionales pasan de `campo: T | undefined` a `campo?: T`, que es lo que codegen
  entiende. En TypeScript el consumidor puede omitirlos igual, y ahora además **puede omitirlos
  de verdad** en vez de tener que escribir `undefined`.
- `result` pasa de `'OK' | 'ERROR' | 'WARNING' | 'CONTINUE'` a `string`. La unión de literales
  funciona en la **entrada** (`theme` la usa y pasa), pero en la **salida** ataría el tipo a que
  el backend nunca devuelva un valor nuevo, y romper el parseo de JS por un valor desconocido es
  peor que perder el estrechamiento de tipo. `theme` se mantiene como unión porque ahí el
  conjunto lo definimos nosotros.

- [ ] **Step 2: Reescribir `src/index.tsx` conservando la API pública**

```tsx
import Khipu from './NativeKhipu';
import type {
  KhipuColors,
  KhipuEvent,
  KhipuOptions,
  KhipuResult,
  StartOperationOptions,
} from './NativeKhipu';

export type {
  KhipuColors,
  KhipuEvent,
  KhipuOptions,
  KhipuResult,
  StartOperationOptions,
};

export function startOperation(
  options: StartOperationOptions
): Promise<KhipuResult> {
  return Khipu.startOperation(options);
}
```

Desaparece el `Proxy` con el `LINKING_ERROR`: `TurboModuleRegistry.getEnforcing` ya lanza un error
descriptivo cuando el módulo no está enlazado, y hacerlo dos veces solo confunde.

- [ ] **Step 3: Declarar `codegenConfig`**

En `package.json`, al mismo nivel que `react-native-builder-bob`:

```json
  "codegenConfig": {
    "name": "KhipuSpec",
    "type": "modules",
    "jsSrcsDir": "src",
    "android": {
      "javaPackageName": "com.khipu"
    }
  },
```

Ojo con los tres nombres, que son distintos y se confunden con facilidad:

| Cosa | Valor | De dónde sale |
|---|---|---|
| `codegenConfig.name` | `KhipuSpec` | Convención `<Nombre>Spec` del template oficial. Da el nombre del header generado |
| `#import` en iOS | `<KhipuSpec/KhipuSpec.h>` | Se deriva del anterior |
| Protocolo / clase abstracta | `NativeKhipuSpec` | Se deriva del **nombre del archivo** `src/NativeKhipu.ts` |

- [ ] **Step 4: Comprobar que codegen parsea y genera**

```bash
cd /Users/edavis/git/react-native-khipu
node -e '
const {TypeScriptParser} = require("./example/node_modules/@react-native/codegen/lib/parsers/typescript/parser");
const schema = new TypeScriptParser().parseFile("src/NativeKhipu.ts");
const mod = Object.values(schema.modules)[0];
console.log("aliases:", Object.keys(mod.aliasMap).join(", "));
for (const g of ["GenerateModuleObjCpp","GenerateModuleJavaSpec","GenerateModuleJniCpp","GenerateModuleH"]) {
  const out = require("./example/node_modules/@react-native/codegen/lib/generators/modules/"+g)
    .generate("Khipu", schema, undefined, undefined, "com.khipu");
  console.log("OK", g, "->", [...out.keys()].join(", "));
}'
```

Esperado: los cinco aliases y los cuatro generadores en OK.

- [ ] **Step 5: Correr el test de contrato**

```bash
yarn test key-contract
```

Esperado: **pasan todos**. El spec ya existe y sus claves coinciden con lo que Swift y Kotlin leen
y escriben hoy. Si falla, hay una clave que se escribió mal en el spec.

- [ ] **Step 6: Typecheck y lint**

```bash
yarn typecheck && yarn lint && yarn test
```

- [ ] **Step 7: Commit**

```bash
git add src/NativeKhipu.ts src/index.tsx package.json
git commit -m "feat: declarar el spec de codegen del modulo Khipu"
```

---

## Task 3: iOS — conformar el protocolo generado

**Files:**
- Create: `ios/Khipu.h`
- Modify: `ios/Khipu.mm`
- Modify: `ios/Khipu.swift`
- Modify: `ios/Khipu-Bridging-Header.h`

**Interfaces:**
- Consumes: `NativeKhipuSpec` y `JS::NativeKhipu::StartOperationOptions`, generados por Task 2.
- Produces: `@objc(Khipu) class KhipuImpl` en Swift, con
  `startOperation(_ options: NSDictionary, resolve:reject:)`. Nada fuera de iOS lo consume.

- [ ] **Step 1: Escribir la cabecera**

Crear `ios/Khipu.h`:

```objc
#import <KhipuSpec/KhipuSpec.h>

@interface Khipu : NSObject <NativeKhipuSpec>

@end
```

El nombre del header (`KhipuSpec`) viene de `codegenConfig.name`; el del protocolo
(`NativeKhipuSpec`) viene del nombre del archivo `src/NativeKhipu.ts`. Son distintos a propósito.

- [ ] **Step 2: Reescribir el `.mm` como TurboModule**

Reemplazar el contenido completo de `ios/Khipu.mm`. Deja de usar `RCT_EXTERN_MODULE` y pasa a
conformar el protocolo generado, delegando en la clase Swift:

```objc
#import "Khipu.h"
#import "react_native_khipu-Swift.h"

@implementation Khipu {
  KhipuImpl *_impl;
}

RCT_EXPORT_MODULE()

- (instancetype)init
{
  if (self = [super init]) {
    _impl = [KhipuImpl new];
  }
  return self;
}

- (void)startOperation:(JS::NativeKhipu::StartOperationOptions &)options
               resolve:(RCTPromiseResolveBlock)resolve
                reject:(RCTPromiseRejectBlock)reject
{
  // El struct generado es una vista sobre el NSDictionary original. Se pasa el
  // diccionario crudo a Swift, que ya sabe leerlo, en vez de reconstruirlo campo
  // por campo: el struct garantiza en compilacion que las claves existen, que es
  // lo que se buscaba, y el parseo sigue viviendo en un solo lugar.
  [_impl startOperation:(NSDictionary *)options.unsafeRawValue
                resolve:resolve
                 reject:reject];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeKhipuSpecJSI>(params);
}

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

@end
```

> Si `unsafeRawValue` no existe en la versión de codegen instalada, mirar el `Khipu.h` generado en
> `example/ios/build/generated/ios/NativeKhipuSpec/` para ver el nombre real del accesor al
> diccionario subyacente, y ajustar. **No inventarlo**: el archivo generado es la fuente de verdad.

- [ ] **Step 3: Renombrar la clase Swift**

En `ios/Khipu.swift`, la clase Swift ya no puede llamarse `Khipu` — ese nombre lo ocupa ahora la
clase ObjC del Step 1. Cambiar:

```swift
@objc(Khipu)
class Khipu: NSObject {
```

por:

```swift
@objc(KhipuImpl)
public class KhipuImpl: NSObject {
```

y el método, que deja de necesitar el selector de `RCT_EXTERN_METHOD`:

```swift
    @objc
    public func startOperation(_ startOperationOptions: NSDictionary,
                               resolve: @escaping RCTPromiseResolveBlock,
                               reject: @escaping RCTPromiseRejectBlock) -> Void {
```

El cuerpo del método **no cambia**, incluido el `presenter()` que dejó el Plan 1. Ojo: `presenter()`
es `private static` y se invoca como `Khipu.presenter()` — hay que cambiar esa llamada a
`KhipuImpl.presenter()`.

- [ ] **Step 4: Instalar y generar**

```bash
cd example/ios && pod install && cd ../..
```

Esperado en el output: una línea mencionando codegen y `NativeKhipuSpec`.

```bash
find example/ios/build/generated/ios -maxdepth 2 -name "KhipuSpec*"
```

Esperado: `KhipuSpec/KhipuSpec.h` y `KhipuSpec/KhipuSpec-generated.mm`. **Abrir el `.h` y
confirmar el nombre real del protocolo** antes de seguir: si no dice `NativeKhipuSpec`, ajustar
`ios/Khipu.h` a lo que diga el archivo generado, que es la fuente de verdad.

- [ ] **Step 5: Construir iOS**

```bash
yarn example ios
```

Si falla con "unknown type name `JS::NativeKhipu::StartOperationOptions`", el namespace `JS::` no
calza: se deriva del nombre del archivo `src/NativeKhipu.ts`, no de `codegenConfig.name`. Abrir el
`KhipuSpec.h` generado y copiar el namespace exacto que declare.

Si falla con `'KhipuSpec/KhipuSpec.h' file not found`, entonces sí es `codegenConfig.name`: debe
decir `KhipuSpec` y coincidir con el `#import`.

- [ ] **Step 6: Pago completo en iOS**

Un pago real, verificando fuentes, imágenes y colores. Y **repetir el harness del modal** del
Plan 1: la migración a TurboModule no debe haber reintroducido el bug del presenter.

- [ ] **Step 7: Comprobar que el contrato de iOS ahora es de compilación**

Renombrar una clave en el spec y comprobar que **iOS deja de compilar**, que es la garantía nueva
que compra esta tarea:

```bash
sed -i '' 's/  titleImageUrl?: string;/  titleImageUrlXX?: string;/' src/NativeKhipu.ts
cd example/ios && pod install && cd ../..
yarn example ios
```

Esperado: error de compilación en el `.mm` o en el struct generado. Revertir:

```bash
git checkout src/NativeKhipu.ts && cd example/ios && pod install && cd ../..
```

- [ ] **Step 8: Commit**

```bash
git add ios/ src/
git commit -m "feat(ios): implementar Khipu como TurboModule sobre el spec generado"
```

---

## Task 4: Android — extender la clase generada

**Files:**
- Modify: `android/src/main/java/com/khipu/KhipuModule.kt`
- Modify: `android/src/main/java/com/khipu/KhipuPackage.kt`
- Modify: `android/build.gradle`

**Interfaces:**
- Consumes: `NativeKhipuSpec` de Task 2 —
  `public abstract void startOperation(ReadableMap options, Promise promise)`.
- Produces: `KhipuModule : NativeKhipuSpec` y `KhipuPackage : BaseReactPackage`.

- [ ] **Step 1: Habilitar codegen en Gradle**

En `android/build.gradle`, al nivel superior:

```groovy
react {
  jsRootDir = file("../src/")
  libraryName = "KhipuSpec"
  codegenJavaPackageName = "com.khipu"
}
```

`libraryName` debe coincidir con `codegenConfig.name` de Task 2 Step 3.

- [ ] **Step 2: Cambiar la clase base del módulo**

En `android/src/main/java/com/khipu/KhipuModule.kt`:

```kotlin
class KhipuModule(reactContext: ReactApplicationContext) :
  NativeKhipuSpec(reactContext) {
```

Eliminar el import de `ReactContextBaseJavaModule` y agregar el de la clase generada.

**El paquete hay que leerlo, no adivinarlo.** Con `codegenJavaPackageName = "com.khipu"` debería
ser `com.khipu.NativeKhipuSpec`, pero codegen a veces la deja en `com.facebook.fbreact.specs`.
Buscar el archivo generado después de la primera corrida de Gradle y usar el paquete que declare:

```bash
find example/android -path "*generated*" -name "NativeKhipuSpec.java" -exec head -20 {} \;
```

Eliminar el `getName()` — lo provee la clase generada:

```kotlin
  override fun getName(): String {
    return NAME
  }
```

Y el método pasa de `@ReactMethod fun` a `override fun`, porque ahora implementa un abstracto:

```kotlin
  override fun startOperation(operationOptions: ReadableMap, promise: Promise) {
```

Se elimina también el import de `ReactMethod`, que deja de usarse.

**El cuerpo del método no cambia.** Codegen sigue entregando un `ReadableMap`, así que toda la
lectura por claves de string sigue igual — y por eso el test de Task 1 es permanente.

- [ ] **Step 3: Cambiar el package**

Reemplazar `android/src/main/java/com/khipu/KhipuPackage.kt`:

```kotlin
package com.khipu

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider

class KhipuPackage : BaseReactPackage() {
  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
    return if (name == KhipuModule.NAME) KhipuModule(reactContext) else null
  }

  override fun getReactModuleInfoProvider() = ReactModuleInfoProvider {
    mapOf(
      KhipuModule.NAME to ReactModuleInfo(
        name = KhipuModule.NAME,
        className = KhipuModule.NAME,
        canOverrideExistingModule = false,
        needsEagerInit = false,
        isCxxModule = false,
        isTurboModule = true
      )
    )
  }
}
```

- [ ] **Step 4: Compilar Android**

```bash
cd example/android && ./gradlew assembleDebug --no-daemon && cd ../..
```

Si falla con "Unresolved reference: NativeKhipuSpec", codegen no corrió: revisar que el bloque
`react { }` del Step 1 tenga `libraryName = "NativeKhipu"` igual que el `codegenConfig.name`.

- [ ] **Step 5: Pago completo en Android**

```bash
yarn example android
```

Un pago real de extremo a extremo. Es una migración de la clase base del módulo, no un cambio
cosmético: hay que verlo funcionar.

- [ ] **Step 6: Correr el test de contrato**

```bash
yarn test key-contract
```

Esperado: pasan todos. Confirma que renombrar la clase base no rompió los extractores.

- [ ] **Step 7: Commit**

```bash
git add android/
git commit -m "feat(android): implementar KhipuModule como TurboModule sobre el spec generado"
```

---

## Task 5: Paridad entre plataformas y release

**Files:**
- Modify: `README.md`
- Modify: `package.json` (versión, vía `release-it`)

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: la versión publicada.

- [ ] **Step 1: Verificar paridad de opciones**

Con el mismo `startOperation` en las dos plataformas, pasando **todas** las opciones:

```tsx
startOperation({
  operationId: id,
  options: {
    title: 'Paridad',
    titleImageUrl: 'https://s3.amazonaws.com/static.khipu.com/buttons/2024/200x75-black.png',
    locale: 'es_CL',
    theme: 'dark',
    skipExitPage: false,
    skipExitSuccessPage: false,
    showFooter: true,
    showMerchantLogo: true,
    showPaymentDetails: true,
    colors: { darkPrimary: '#8347AD', darkTopBarContainer: '#3CB4E5' },
  },
});
```

Verificar en iOS y Android que **cada** opción tiene el mismo efecto visible: el título, la imagen
del top bar, el tema oscuro, el footer, el logo, el detalle del pago y los dos colores. Es la
verificación de que el contrato sobrevivió a la migración en los dos lados.

Anotar cualquier diferencia. Una opción que funcione en una plataforma y no en la otra es
exactamente el bug que este plan viene a hacer imposible.

- [ ] **Step 2: Verificar que la API pública no cambió**

```bash
yarn prepare
cat lib/typescript/src/index.d.ts
```

Comparar contra la versión anterior: `startOperation` debe conservar su firma, y los tipos
exportados deben seguir siendo los mismos nombres. La única diferencia esperada es
`campo?: T` en vez de `campo: T | undefined`, y `result: string`.

- [ ] **Step 3: Documentar el cambio de tipos en el README**

Agregar a la sección de uso una nota corta: los campos opcionales ahora se declaran con `?` y se
pueden omitir; `result` pasa a `string` para no romperse si el backend agrega un valor nuevo.
Ningún comercio necesita cambiar su código.

- [ ] **Step 4: Verificación completa**

```bash
yarn lint && yarn typecheck && yarn test && yarn prepare
cd example/ios && pod install && cd ../..
yarn example ios
yarn example android
```

- [ ] **Step 5: Liberar**

```bash
yarn release
```

**Minor** (`2.16.0`). El CHANGELOG debe decir que el módulo pasa a TurboModule en las dos
plataformas, que la API de JS no cambia, y el ajuste de tipos del Step 3.

---

## Notas de ejecución

**Este plan no se puede liberar a medias.** `codegenConfig` afecta a las dos plataformas desde el
momento en que se declara: si se libera con iOS migrado y Android sin migrar, Android queda con
una clase generada que nadie extiende. Las tareas 2, 3 y 4 van juntas al mismo release.

**El Task 1 es el que sobrevive al plan.** El test de contrato queda para siempre porque el Java
generado no protege ninguna clave, y ese es el hallazgo que más vale de todo este trabajo.
