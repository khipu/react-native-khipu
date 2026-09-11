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

  # Public headers go under the MODULE directory (underscores) rather than the
  # POD one (hyphens, the default). Without this, the Swift-generated header on
  # RN 0.75.5 asks for <react_native_khipu/react_native_khipu.h> and does not
  # resolve. See ios/react_native_khipu.h.
  s.header_dir   = "react_native_khipu"

  # React Native >=0.75 resolves the SDK from git via Swift Package Manager,
  # which keeps the plugin clear of the CocoaPods trunk freeze on 2026-12-02:
  # the whole Khipu tree (KhipuClientIOS, KhenshinProtocolSwift,
  # KhenshinSecureMessage and their transitives) comes from git, not trunk.
  #
  # Below 0.75 the helper does not exist and we fall back to the pod, frozen at
  # the last version published to trunk before that date. Those merchants need
  # to upgrade React Native to get newer SDK releases.
  #
  # 2.16.6 or newer is required: an unreadable socket frame used to kill the
  # merchant's app, and a terminal message that failed to parse left the payer
  # with no way out and no callback (IKW-1234). Same defect class Android had,
  # with the opposite symptom. 2.16.6 also pins Starscream at 4.0.8 (IKW-1235).
  #
  # The SPM path requires the app to call khipu_fix_spm_modulemaps from its
  # post_install. See ios/khipu_spm_fix.rb and the README.
  if respond_to?(:spm_dependency, true)
    spm_dependency(s,
      url: "https://github.com/khipu/KhipuClientIOS.git",
      requirement: { kind: "exactVersion", version: "2.16.6" },
      products: ["KhipuClientIOS"]
    )
  else
    s.dependency "KhipuClientIOS", "2.16.6"
  end

  # install_modules_dependencies exists from React Native 0.71 on. The guard is
  # load-bearing: without it the podspec dies with "undefined method
  # install_modules_dependencies" on anything older, and peerDependencies
  # declares react-native "*".
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
