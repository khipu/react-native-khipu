import KhipuClientIOS

@objc(KhipuImpl)
public class KhipuImpl: NSObject {

    /// Key window on iOS 12, where scenes do not exist and
    /// `UIApplication.shared.windows` is the only source.
    ///
    /// Marked deprecated in 13.0 on purpose, so modern apps that never take
    /// this branch do not get the iOS 15 deprecation warning.
    @available(iOS, introduced: 2.0, deprecated: 13.0)
    private static func legacyKeyWindow() -> UIWindow? {
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
            ?? UIApplication.shared.windows.first
    }

    /// Topmost controller of the active scene, so we present on top of
    /// whatever the merchant has up instead of dismissing it.
    ///
    /// Private and not a UIViewController extension on purpose: the plugin is
    /// statically linked into the merchant app, so a public name like
    /// `topMostViewController()` could collide with theirs.
    ///
    /// The `#available` is load-bearing: RN 0.70-0.72 declare an iOS 12.4
    /// floor and `connectedScenes` is 13+. `UIWindowScene.keyWindow` is
    /// deliberately avoided, being 15+.
    private static func presenter() -> UIViewController? {
        var window: UIWindow?

        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
            else { return nil }
            window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        } else {
            window = legacyKeyWindow()
        }

        guard let keyWindow = window else { return nil }

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

        if(startOperationOptions["options"] != nil) {

            let options = startOperationOptions["options"] as! NSDictionary

            if (options["title"] != nil) {
                optionsBuilder = optionsBuilder.topBarTitle(options["title"]! as! String)
            }

            if (options["titleImageUrl"] != nil) {
                            optionsBuilder = optionsBuilder.topBarImageUrl(options["titleImageUrl"]! as! String)
            }

            if (options["skipExitPage"] != nil) {
                optionsBuilder = optionsBuilder.skipExitPage(options["skipExitPage"]! as! Bool)
            }

            if (options["skipExitSuccessPage"] != nil) {
                optionsBuilder = optionsBuilder.skipExitSuccessPage(options["skipExitSuccessPage"]! as! Bool)
            }

            if (options["showFooter"] != nil) {
                optionsBuilder = optionsBuilder.showFooter(options["showFooter"]! as! Bool)
            }

            if (options["showMerchantLogo"] != nil) {
                optionsBuilder = optionsBuilder.showMerchantLogo(options["showMerchantLogo"]! as! Bool)
            }

            if (options["showPaymentDetails"] != nil) {
                optionsBuilder = optionsBuilder.showPaymentDetails(options["showPaymentDetails"]! as! Bool)
            }

            if (options["locale"] != nil) {
                optionsBuilder = optionsBuilder.locale(options["locale"]! as! String)
            }

            if (options["theme"] != nil) {
                let theme = options["theme"]! as! String
                if(theme == "light") {
                    optionsBuilder = optionsBuilder.theme(.light)
                } else if (theme == "dark") {
                    optionsBuilder = optionsBuilder.theme(.dark)
                } else if (theme == "system") {
                    optionsBuilder = optionsBuilder.theme(.system)
                }
            }

            if (options["colors"] != nil) {
                let colors = options["colors"] as! NSDictionary

                var colorsBuilder = KhipuColors.Builder()

                if (colors["lightBackground"] != nil) {
                    colorsBuilder = colorsBuilder.lightBackground(colors["lightBackground"]! as! String)
                }
                if (colors["lightOnBackground"] != nil) {
                    colorsBuilder = colorsBuilder.lightOnBackground(colors["lightOnBackground"]! as! String)
                }
                if (colors["lightPrimary"] != nil) {
                    colorsBuilder = colorsBuilder.lightPrimary(colors["lightPrimary"]! as! String)
                }
                if (colors["lightOnPrimary"] != nil) {
                    colorsBuilder = colorsBuilder.lightOnPrimary(colors["lightOnPrimary"]! as! String)
                }
                if (colors["lightTopBarContainer"] != nil) {
                    colorsBuilder = colorsBuilder.lightTopBarContainer(colors["lightTopBarContainer"]! as! String)
                }
                if (colors["lightOnTopBarContainer"] != nil) {
                    colorsBuilder = colorsBuilder.lightOnTopBarContainer(colors["lightOnTopBarContainer"]! as! String)
                }
                if (colors["darkBackground"] != nil) {
                    colorsBuilder = colorsBuilder.darkBackground(colors["darkBackground"]! as! String)
                }
                if (colors["darkOnBackground"] != nil) {
                    colorsBuilder = colorsBuilder.darkOnBackground(colors["darkOnBackground"]! as! String)
                }
                if (colors["darkPrimary"] != nil) {
                    colorsBuilder = colorsBuilder.darkPrimary(colors["darkPrimary"]! as! String)
                }
                if (colors["darkOnPrimary"] != nil) {
                    colorsBuilder = colorsBuilder.darkOnPrimary(colors["darkOnPrimary"]! as! String)
                }
                if (colors["darkTopBarContainer"] != nil) {
                    colorsBuilder = colorsBuilder.darkTopBarContainer(colors["darkTopBarContainer"]! as! String)
                }
                if (colors["darkOnTopBarContainer"] != nil) {
                    colorsBuilder = colorsBuilder.darkOnTopBarContainer(colors["darkOnTopBarContainer"]! as! String)
                }


                optionsBuilder = optionsBuilder.colors(colorsBuilder.build())
            }
        }

        DispatchQueue.main.async {
            guard let presenter = KhipuImpl.presenter() else {
                reject("NO_PRESENTER", "No view controller available to present from", NSError())
                return
            }

            guard let operationId = startOperationOptions["operationId"] else {
                reject("NO_OPERATION_ID", "OperationId is needed to start the operation", NSError())
                return
            }

            KhipuLauncher.launch(presenter: presenter,
                                 operationId: operationId as! String,
                                 options: optionsBuilder.build()) { result in
                resolve([
                    "operationId": result.operationId,
                    "result": result.result,
                    "exitTitle": result.exitTitle,
                    "exitMessage": result.exitMessage,
                    "exitUrl": result.exitUrl as Any,
                    "failureReason": result.failureReason as Any,
                    "continueUrl": result.continueUrl as Any,
                    "events": result.events.map({ event in
                        return [
                            "name": event.name,
                            "type": event.type,
                            "timestamp": event.timestamp
                        ]
                    })
                ])
            }
        }
    }
}
