# Changelog

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
