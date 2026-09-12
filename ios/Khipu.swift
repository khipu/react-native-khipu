import KhipuClientIOS

@objc(KhipuImpl)
public class KhipuImpl: NSObject {

    /// Topmost controller of the active scene, so we present on top of
    /// whatever the merchant has up instead of dismissing it.
    ///
    /// Private and not a UIViewController extension on purpose: the plugin is
    /// statically linked into the merchant app, so a public name like
    /// `topMostViewController()` could collide with theirs.
    ///
    /// No `#available` guard: `min_ios_version_supported` is 13.4 on our RN
    /// floor and `connectedScenes` is 13+. `UIWindowScene.keyWindow` is
    /// deliberately avoided, being 15+.
    private static func presenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        else { return nil }

        guard let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else { return nil }

        var controller = keyWindow.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }

    @objc
    public func startOperation(_ startOperationOptions: NSDictionary,
                               resolve: @escaping RCTPromiseResolveBlock,
                               reject: @escaping RCTPromiseRejectBlock) -> Void {

        var optionsBuilder = KhipuOptions.Builder()

        if(startOperationOptions[KhipuKeyOptions] != nil) {

            let options = startOperationOptions[KhipuKeyOptions] as! NSDictionary

            if (options[KhipuKeyTitle] != nil) {
                optionsBuilder = optionsBuilder.topBarTitle(options[KhipuKeyTitle]! as! String)
            }

            if (options[KhipuKeyTitleImageUrl] != nil) {
                            optionsBuilder = optionsBuilder.topBarImageUrl(options[KhipuKeyTitleImageUrl]! as! String)
            }

            if (options[KhipuKeySkipExitPage] != nil) {
                optionsBuilder = optionsBuilder.skipExitPage(options[KhipuKeySkipExitPage]! as! Bool)
            }

            if (options[KhipuKeySkipExitSuccessPage] != nil) {
                optionsBuilder = optionsBuilder.skipExitSuccessPage(options[KhipuKeySkipExitSuccessPage]! as! Bool)
            }

            if (options[KhipuKeyShowFooter] != nil) {
                optionsBuilder = optionsBuilder.showFooter(options[KhipuKeyShowFooter]! as! Bool)
            }

            if (options[KhipuKeyShowMerchantLogo] != nil) {
                optionsBuilder = optionsBuilder.showMerchantLogo(options[KhipuKeyShowMerchantLogo]! as! Bool)
            }

            if (options[KhipuKeyShowPaymentDetails] != nil) {
                optionsBuilder = optionsBuilder.showPaymentDetails(options[KhipuKeyShowPaymentDetails]! as! Bool)
            }

            if (options[KhipuKeyLocale] != nil) {
                optionsBuilder = optionsBuilder.locale(options[KhipuKeyLocale]! as! String)
            }

            if (options[KhipuKeyTheme] != nil) {
                let theme = options[KhipuKeyTheme]! as! String
                if(theme == "light") {
                    optionsBuilder = optionsBuilder.theme(.light)
                } else if (theme == "dark") {
                    optionsBuilder = optionsBuilder.theme(.dark)
                } else if (theme == "system") {
                    optionsBuilder = optionsBuilder.theme(.system)
                }
            }

            if (options[KhipuKeyColors] != nil) {
                let colors = options[KhipuKeyColors] as! NSDictionary

                var colorsBuilder = KhipuColors.Builder()

                if (colors[KhipuKeyLightBackground] != nil) {
                    colorsBuilder = colorsBuilder.lightBackground(colors[KhipuKeyLightBackground]! as! String)
                }
                if (colors[KhipuKeyLightOnBackground] != nil) {
                    colorsBuilder = colorsBuilder.lightOnBackground(colors[KhipuKeyLightOnBackground]! as! String)
                }
                if (colors[KhipuKeyLightPrimary] != nil) {
                    colorsBuilder = colorsBuilder.lightPrimary(colors[KhipuKeyLightPrimary]! as! String)
                }
                if (colors[KhipuKeyLightOnPrimary] != nil) {
                    colorsBuilder = colorsBuilder.lightOnPrimary(colors[KhipuKeyLightOnPrimary]! as! String)
                }
                if (colors[KhipuKeyLightTopBarContainer] != nil) {
                    colorsBuilder = colorsBuilder.lightTopBarContainer(colors[KhipuKeyLightTopBarContainer]! as! String)
                }
                if (colors[KhipuKeyLightOnTopBarContainer] != nil) {
                    colorsBuilder = colorsBuilder.lightOnTopBarContainer(colors[KhipuKeyLightOnTopBarContainer]! as! String)
                }
                if (colors[KhipuKeyDarkBackground] != nil) {
                    colorsBuilder = colorsBuilder.darkBackground(colors[KhipuKeyDarkBackground]! as! String)
                }
                if (colors[KhipuKeyDarkOnBackground] != nil) {
                    colorsBuilder = colorsBuilder.darkOnBackground(colors[KhipuKeyDarkOnBackground]! as! String)
                }
                if (colors[KhipuKeyDarkPrimary] != nil) {
                    colorsBuilder = colorsBuilder.darkPrimary(colors[KhipuKeyDarkPrimary]! as! String)
                }
                if (colors[KhipuKeyDarkOnPrimary] != nil) {
                    colorsBuilder = colorsBuilder.darkOnPrimary(colors[KhipuKeyDarkOnPrimary]! as! String)
                }
                if (colors[KhipuKeyDarkTopBarContainer] != nil) {
                    colorsBuilder = colorsBuilder.darkTopBarContainer(colors[KhipuKeyDarkTopBarContainer]! as! String)
                }
                if (colors[KhipuKeyDarkOnTopBarContainer] != nil) {
                    colorsBuilder = colorsBuilder.darkOnTopBarContainer(colors[KhipuKeyDarkOnTopBarContainer]! as! String)
                }


                optionsBuilder = optionsBuilder.colors(colorsBuilder.build())
            }
        }

        DispatchQueue.main.async {
            guard let presenter = KhipuImpl.presenter() else {
                reject("NO_PRESENTER", "No view controller available to present from", NSError())
                return
            }

            guard let operationId = startOperationOptions[KhipuKeyOperationId] else {
                reject("NO_OPERATION_ID", "OperationId is needed to start the operation", NSError())
                return
            }

            KhipuLauncher.launch(presenter: presenter,
                                 operationId: operationId as! String,
                                 options: optionsBuilder.build()) { result in
                resolve([
                    KhipuKeyOperationId: result.operationId,
                    KhipuKeyResult: result.result,
                    KhipuKeyExitTitle: result.exitTitle,
                    KhipuKeyExitMessage: result.exitMessage,
                    KhipuKeyExitUrl: result.exitUrl as Any,
                    KhipuKeyFailureReason: result.failureReason as Any,
                    KhipuKeyContinueUrl: result.continueUrl as Any,
                    KhipuKeyEvents: result.events.map({ event in
                        return [
                            KhipuKeyName: event.name,
                            KhipuKeyType: event.type,
                            KhipuKeyTimestamp: event.timestamp
                        ]
                    })
                ])
            }
        }
    }
}
