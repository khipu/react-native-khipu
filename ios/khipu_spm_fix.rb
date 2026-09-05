# Rodea un bug de React Native, verificado en 0.87.1.
#
# scripts/cocoapods/spm.rb aplana el build dir de un pod que consume paquetes
# SPM con linking estatico, para evitar module maps duplicados, y despues
# reescribe la referencia al modulemap en los xcconfig agregados con:
#
#   gsub("${PODS_CONFIGURATION_BUILD_DIR}/#{pod_name}/#{pod_name}.modulemap", ...)
#
# Pero CocoaPods nombra el modulemap con el MODULE name y el directorio con el
# POD name. Para nosotros son "react_native_khipu" y "react-native-khipu": el
# gsub nunca calza, la reescritura queda en un no-op silencioso, y el build
# falla con "module map file ... not found".
#
# Afecta a cualquier pod con guion en el nombre, o sea a casi toda libreria de
# la comunidad, no solo a Khipu.
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
# Retirar esta funcion cuando el arreglo este upstream y el piso de React
# Native que soportemos lo incluya.
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
