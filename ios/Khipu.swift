import KhipuClientIOS

@objc(Khipu)
class Khipu: NSObject {

    /// Ventana clave en iOS 12, donde no existen las escenas y
    /// `UIApplication.shared.windows` es la unica fuente disponible.
    ///
    /// Anotado como deprecado en 13.0 a proposito: eso evita que el compilador
    /// emita el warning de deprecacion de iOS 15 en apps modernas, que nunca
    /// ejecutan esta rama.
    @available(iOS, introduced: 2.0, deprecated: 13.0)
    private static func legacyKeyWindow() -> UIWindow? {
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
            ?? UIApplication.shared.windows.first
    }

    /// Devuelve el controlador mas alto de la escena activa, para presentar
    /// encima de lo que sea que el comercio tenga arriba en vez de cerrarselo.
    ///
    /// Privado a proposito, y no una extension de UIViewController: el plugin
    /// se enlaza estaticamente en la app del comercio, asi que un nombre
    /// publico como `topMostViewController()` puede colisionar con el suyo.
    ///
    /// El `#available` no es decorativo: React Native 0.70 a 0.72 declaran un
    /// piso de iOS 12.4, y `connectedScenes` es 13+. Sin el guard, esta
    /// libreria no compila en esos proyectos. Se evita a proposito
    /// `UIWindowScene.keyWindow`, que es 15+.
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

    @objc(startOperation:withResolver:withRejecter:)
    func startOperation(startOperationOptions: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {

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
            guard let presenter = Khipu.presenter() else {
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
