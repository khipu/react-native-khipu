# Matriz de compatibilidad por versión de React Native

**Fecha:** 2026-09-05
**Plugin:** `react-native-khipu@3.0.1` instalado **desde npm**
**Entorno:** Xcode 26.6, macOS arm64, CocoaPods 1.16.2

Ocho versiones de React Native, cada una en una app recién creada, instalando el paquete
publicado y siguiendo **solo el README** — sin usar nada sabido por trabajar en el repo. Esa
restricción es deliberada: la app de ejemplo del repo hereda `metro.config.js`,
`babel.config.js` y `react-native.config.js`, y por eso esconde justo los pasos que al comercio
le faltan.

## Resultados

| RN | Rama del podspec | `pod install` | Build directo | Si falla, causa | Workaround verificado |
|---|---|---|---|---|---|
| 0.72.17 | pod | ✅ | ❌ | React Native — Yoga | `-Wno-deprecated-literal-operator` ✅ |
| 0.74.7 | pod | ✅ | ✅ | — | — |
| 0.75.5 | SPM | ✅ | ✅ | — | — |
| 0.76.9 | SPM | ✅ | ❌ | React Native — `fmt` | `fmt` compilado como C++17 ✅ |
| 0.80.3 | SPM | ✅ | ❌ | React Native — `fmt` | `fmt` compilado como C++17 ✅ |
| 0.83.10 | SPM | ✅ | ✅ | — | — |
| 0.85.0 | SPM | ✅ | ✅ | — | — |
| 0.87.1 | SPM | ✅ | ✅ | — | — |

**En las ocho, `pod install` y la rama del podspec funcionaron correctamente.** El corte pod/SPM
cae donde debe: `spm_dependency` existe desde RN 0.75.

## Los dos bugs de React Native

Ambos verificados **con control**: se desinstaló `react-native-khipu`, se confirmó `0` ocurrencias
en el `Podfile.lock`, y el build falló idéntico. No son nuestros.

### Yoga en 0.72

```
node_modules/react-native/ReactCommon/yoga/yoga/YGValue.h:77:27:
error: identifier '_pt' preceded by whitespace in a literal operator declaration
is deprecated [-Werror,-Wdeprecated-literal-operator]
```

El clang de Xcode 26 trata ese warning como error. Workaround en el `post_install`:

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

### `fmt` en 0.76 y 0.80

```
Pods/fmt/include/fmt/format-inl.h:1387:35:
error: call to consteval function 'fmt::basic_format_string<...>'
is not a constant expression
```

Bug conocido: [facebook/react-native#55601](https://github.com/facebook/react-native/issues/55601).
El clang de Xcode 26 endureció la validación de `consteval` y el `fmt` que empaqueta React Native
no la cumple. **Arreglado en RN 0.84+**, que sube la versión de `fmt`.

**`FMT_CONSTEVAL=` NO funciona**, aunque varias guías de la comunidad lo proponen. Se verificó que
el define llega al `pbxproj` y el build falla igual. Lo que sí funciona es compilar `fmt` contra
C++17, donde `consteval` no existe:

```ruby
installer.pods_project.targets.each do |t|
  next unless t.name == 'fmt'
  t.build_configurations.each do |c|
    c.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++17'
  end
end
```

## Lo que este barrido encontró, y que no habría salido de leer código

**Un bug nuestro que rompía tres versiones.** El helper `khipu_fix_spm_modulemaps` de `3.0.0`
reescribía la referencia al modulemap de todos los pods sin comprobar si `spm.rb` los había
aplanado. En 0.75, 0.83 y 0.85 eso apuntaba a un archivo inexistente y rompía un build que
funcionaba. Corregido en `3.0.1`.

**Una atribución errónea.** El fallo de 0.83 se registró primero como bug de React Native
(`RCTSwiftUI.modulemap`) y estuvo a punto de documentarse así públicamente. Era nuestro. Se
detectó porque el resultado no cuadraba: el workaround de `fmt` no podía arreglar un error de
`RCTSwiftUI`, y en vez de anotarlo como éxito se aisló la variable.

**La lección de método:** verificar una combinación de entorno y generalizar produce la misma
falsa confianza que no verificar. Durante este trabajo pasó tres veces — con `use_frameworks!`
medido en un solo Xcode, con la predicción de que 0.74 fallaría, y con el helper probado en una
sola versión de RN.

## Casillas abiertas

- ~~**Ningún pago se ejerció en runtime**~~ y ~~**Android no se barrió por versión**~~ — ambas
  cerradas el 2026-09-06 por [`matriz-pagos-2026-09-06.md`](matriz-pagos-2026-09-06.md), que midió
  un pago real en las dos plataformas versión por versión. Resultado: 7 de 8; **Android en 0.72 no
  compila**, por una cadena de cuatro bloqueos que ese documento detalla.
- **`openApp` sigue sin verificarse en dispositivo físico** en ninguna de las cuatro
  integraciones de Khipu.
