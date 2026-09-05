require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

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

  # React Native >=0.75 resuelve el SDK desde git con Swift Package Manager, lo
  # que deja al plugin inmune al freeze del trunk de CocoaPods del 2026-12-02:
  # todo el arbol de Khipu (KhipuClientIOS, KhenshinProtocolSwift,
  # KhenshinSecureMessage y sus transitivas) sale de git y no del trunk.
  #
  # Por debajo de 0.75 el helper no existe y se cae al pod, congelado en la
  # ultima version publicada en trunk antes de esa fecha. Esos comercios suben
  # de React Native para recibir versiones nuevas del SDK.
  #
  # Ojo: el camino SPM necesita que la app llame a khipu_fix_spm_modulemaps
  # desde su post_install. Ver ios/khipu_spm_fix.rb y el README.
  if respond_to?(:spm_dependency, true)
    spm_dependency(s,
      url: "https://github.com/khipu/KhipuClientIOS.git",
      requirement: { kind: "exactVersion", version: "2.16.5" },
      products: ["KhipuClientIOS"]
    )
  else
    s.dependency "KhipuClientIOS", "2.16.5"
  end

  # install_modules_dependencies existe desde React Native 0.71. El guard NO es
  # decorativo: sin el, el podspec revienta con "undefined method
  # install_modules_dependencies" en cualquier proyecto por debajo de 0.71, y
  # peerDependencies declara react-native "*".
  # Ver https://github.com/facebook/react-native/blob/febf6b7f33fdb4904669f99d795eba4c0f95d7bf/scripts/cocoapods/new_architecture.rb#L79
  if respond_to?(:install_modules_dependencies, true)
    install_modules_dependencies(s)
  else
    s.dependency "React-Core"

    # Don't install the dependencies when we run `pod install` in the old architecture.
    if ENV['RCT_NEW_ARCH_ENABLED'] == '1' then
      s.compiler_flags = folly_compiler_flags + " -DRCT_NEW_ARCH_ENABLED=1"
      s.pod_target_xcconfig    = {
          "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\"",
          "OTHER_CPLUSPLUSFLAGS" => "-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1",
          "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
      }
      s.dependency "React-Codegen"
      s.dependency "RCT-Folly"
      s.dependency "RCTRequired"
      s.dependency "RCTTypeSafety"
      s.dependency "ReactCommon/turbomodule/core"
    end
  end
end
