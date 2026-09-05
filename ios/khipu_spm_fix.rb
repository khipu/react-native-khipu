# Rodea un bug de React Native en el manejo de pods estaticos que consumen
# paquetes SPM.
#
# scripts/cocoapods/spm.rb tiene DOS caminos, y solo uno necesita correccion:
#
#   1. Si el pod es libreria estatica, aplana su build dir para evitar module
#      maps duplicados, fijando en el target
#      CONFIGURATION_BUILD_DIR = ${PODS_CONFIGURATION_BUILD_DIR}. Despues intenta
#      reescribir la referencia al modulemap en los xcconfig agregados con
#
#        gsub("${PODS_CONFIGURATION_BUILD_DIR}/#{pod_name}/#{pod_name}.modulemap", ...)
#
#      Pero CocoaPods nombra el modulemap con el MODULE name y el directorio con
#      el POD name. Para nosotros son "react_native_khipu" y
#      "react-native-khipu": el gsub nunca calza, la reescritura queda en un
#      no-op silencioso, y el build falla con "module map file ... not found".
#      Afecta a cualquier pod con guion en el nombre.
#
#   2. Si el pod NO es estatico, no aplana nada y solo agrega search paths. El
#      path del modulemap en los xcconfig ya es correcto.
#
# Por eso esta funcion solo reescribe los pods que fueron efectivamente
# aplanados. Reescribir en el caso 2 apuntaria a un archivo que no existe y
# ROMPERIA un build que funcionaba -- verificado en React Native 0.75 y 0.85,
# donde spm.rb toma el segundo camino.
#
# Uso, en el Podfile de la app:
#
#   require File.join(
#     File.dirname(`node --print "require.resolve('react-native-khipu/package.json')"`),
#     "ios/khipu_spm_fix.rb"
#   )
#
#   post_install do |installer|
#     react_native_post_install(installer, config[:reactNativePath])
#     khipu_fix_spm_modulemaps(installer)
#   end
#
# El orden importa: react_native_post_install es quien corre la reescritura
# rota, asi que la correccion tiene que ir despues.
#
# Retirar cuando el arreglo este upstream y el piso de React Native que
# soportemos lo incluya.

# Nombres de modulo de los pods que spm.rb aplano en esta instalacion. Un pod
# aplanado se reconoce porque su target quedo con
# CONFIGURATION_BUILD_DIR = ${PODS_CONFIGURATION_BUILD_DIR}.
def khipu_flattened_module_names(installer)
  project = installer.pods_project
  return [] if project.nil?

  installer.pod_targets.filter_map do |pod_target|
    native_target = project.targets.find { |t| t.name == pod_target.name }
    next nil if native_target.nil?

    flattened = native_target.build_configurations.any? do |config|
      native_target.build_settings(config.name)['CONFIGURATION_BUILD_DIR'] ==
        '${PODS_CONFIGURATION_BUILD_DIR}'
    end

    flattened ? [pod_target.name, pod_target.product_module_name] : nil
  end
end

def khipu_fix_spm_modulemaps(installer)
  flattened = khipu_flattened_module_names(installer)

  if flattened.empty?
    Pod::UI.puts "[Khipu] Ningun pod fue aplanado por spm.rb; no hay modulemaps que corregir."
    return
  end

  Pod::UI.puts "[Khipu] Corrigiendo la referencia al modulemap de: " \
               "#{flattened.map(&:first).join(', ')}"

  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.xcconfigs.each do |config_name, config_file|
      %w[OTHER_CFLAGS OTHER_SWIFT_FLAGS].each do |key|
        value = config_file.attributes[key]
        next unless value

        updated = flattened.reduce(value) do |acc, (pod_name, module_name)|
          acc.gsub(
            "${PODS_CONFIGURATION_BUILD_DIR}/#{pod_name}/#{module_name}.modulemap",
            "${PODS_CONFIGURATION_BUILD_DIR}/#{module_name}.modulemap"
          )
        end

        config_file.attributes[key] = updated if updated != value
      end

      config_file.save_as(aggregate_target.xcconfig_path(config_name))
    end
  end
end
