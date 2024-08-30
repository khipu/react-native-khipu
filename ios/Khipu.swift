import KhipuClientIOS

@objc(Khipu)
class Khipu: NSObject {

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
            
            guard let presenter = UIApplication.shared.windows.filter({$0.isKeyWindow}).first?.rootViewController else {
                reject("NO_AVAILABLE_VIEW", "There is no presented UIViewController", NSError())
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
