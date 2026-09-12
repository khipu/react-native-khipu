# Works around a React Native bug in how static pods consuming SPM packages
# are handled.
#
# scripts/cocoapods/spm.rb has TWO paths and only one needs fixing:
#
#   1. For a static-library pod it flattens the build dir to avoid duplicate
#      module maps, then rewrites the modulemap reference in the added xcconfigs
#      with a gsub on "${PODS_CONFIGURATION_BUILD_DIR}/#{pod_name}/#{pod_name}.modulemap".
#      But CocoaPods names the modulemap after the MODULE and the directory
#      after the POD: for us "react_native_khipu" vs "react-native-khipu". The
#      gsub never matches, the rewrite is a silent no-op, and the build fails
#      with "module map file ... not found". Affects any pod with a hyphen.
#
#   2. For a non-static pod nothing is flattened and the xcconfig path is
#      already correct.
#
# So this function only rewrites pods that were actually flattened. Rewriting in
# case 2 would point at a file that does not exist and BREAK a working build --
# verified on React Native 0.75 and 0.85, which take the second path.
#
# Usage, in the app Podfile:
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
# Order matters: react_native_post_install runs the broken rewrite, so the fix
# must come after.
#
# Remove once the fix is upstream and inside our supported React Native floor.

# Module names of the pods spm.rb flattened in this install. A flattened pod is
# recognised by its target having
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
