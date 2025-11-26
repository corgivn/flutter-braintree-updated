import Braintree
import BraintreeDropIn
import Flutter
import PassKit
import UIKit

func makePaymentSummaryItems(from: [String: Any]) -> [PKPaymentSummaryItem]? {
    guard let paymentSummaryItems = from["paymentSummaryItems"] as? [[String: Any]] else {
        return nil
    }

    var outList: [PKPaymentSummaryItem] = []
    for paymentSummaryItem in paymentSummaryItems {
        guard let label = paymentSummaryItem["label"] as? String else {
            return nil
        }
        guard let amount = paymentSummaryItem["amount"] as? Double else {
            return nil
        }
        guard let type = paymentSummaryItem["type"] as? UInt else {
            return nil
        }
        guard let pkType = PKPaymentSummaryItemType.init(rawValue: type) else {
            return nil
        }
        outList.append(
            PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(value: amount), type: pkType)
        )
    }

    return outList
}

public class FlutterBraintreeDropInPlugin: BaseFlutterBraintreePlugin, FlutterPlugin,
    BTThreeDSecureRequestDelegate
{

    private var completionBlock: FlutterResult!
    private var applePayInfo = [String: Any]()
    private var authorization: String!
    private var overlayWindow: UIWindow?

    public func onLookupComplete(
        _ request: BTThreeDSecureRequest, lookupResult result: BTThreeDSecureResult,
        next: @escaping () -> Void
    ) {
        next()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_braintree.drop_in", binaryMessenger: registrar.messenger())

        let instance = FlutterBraintreeDropInPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        completionBlock = result
        // 1. Get the main window's scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            result(
                FlutterError(
                    code: "braintree_error", message: "Could not get window scene.", details: nil))
            isHandlingResult = false
            return
        }

        // 2. Create a new UIWindow
        let newWindow = UIWindow(windowScene: windowScene)
        newWindow.windowLevel = .normal + 1  // Place it above the main app window
        newWindow.backgroundColor = UIColor.black.withAlphaComponent(0.3)  // Dimming effect

        // 3. Create a simple root view controller for the new window
        let blockerVC = UIViewController()
        blockerVC.view.backgroundColor = .clear  // The window's background provides the color
        newWindow.rootViewController = blockerVC

        if call.method == "start" {
            guard !isHandlingResult else {
                returnAlreadyOpenError(result: result)
                return
            }

            isHandlingResult = true

            let threeDSecureRequest = BTThreeDSecureRequest()

            if let email = string(for: "email", in: call) {
                threeDSecureRequest.email = email
            }
            threeDSecureRequest.versionRequested = .version2

            if let billingAddress = dict(for: "billingAddress", in: call) {
                let address = BTThreeDSecurePostalAddress()
                address.givenName = billingAddress["givenName"] as? String
                address.surname = billingAddress["surname"] as? String
                address.phoneNumber = billingAddress["phoneNumber"] as? String
                address.streetAddress = billingAddress["streetAddress"] as? String
                address.extendedAddress = billingAddress["extendedAddress"] as? String
                address.locality = billingAddress["locality"] as? String
                address.region = billingAddress["region"] as? String
                address.postalCode = billingAddress["postalCode"] as? String
                address.countryCodeAlpha2 = billingAddress["countryCodeAlpha2"] as? String
                threeDSecureRequest.billingAddress = address

                // Optional additional information.
                // For best results, provide as many of these elements as possible.
                let info = BTThreeDSecureAdditionalInformation()
                info.shippingAddress = address
                threeDSecureRequest.additionalInformation = info
            }

            let dropInRequest = BTDropInRequest()

            if let amount = string(for: "amount", in: call) {
                threeDSecureRequest.threeDSecureRequestDelegate = self
                threeDSecureRequest.amount = NSDecimalNumber(string: amount)
                dropInRequest.threeDSecureRequest = threeDSecureRequest
            }

            var deviceData: String?
            if let collectDeviceData = bool(for: "collectDeviceData", in: call), collectDeviceData {
                deviceData = PPDataCollector.collectPayPalDeviceData()
            }

            if let vaultManagerEnabled = bool(for: "vaultManagerEnabled", in: call) {
                dropInRequest.vaultManager = vaultManagerEnabled
            }

            if let cardEnabled = bool(for: "cardEnabled", in: call) {
                dropInRequest.cardDisabled = !cardEnabled
            }

            if let paypalEnabled = bool(for: "paypalEnabled", in: call) {
                dropInRequest.paypalDisabled = !paypalEnabled
            }

            // if let paypalInfo = dict(for: "paypalRequest", in: call) {
            //     // if let amount = paypalInfo["amount"] as? String {
            //     //     let paypalRequest = BTPayPalCheckoutRequest(amount: amount)
            //     //     paypalRequest.currencyCode = paypalInfo["currencyCode"] as? String
            //     //     paypalRequest.displayName = paypalInfo["displayName"] as? String
            //     //     paypalRequest.billingAgreementDescription = paypalInfo["billingAgreementDescription"] as? String
            //     //     dropInRequest.payPalRequest = paypalRequest
            //     // } else {
            //         let paypalRequest = BTPayPalVaultRequest()
            //         paypalRequest.displayName = paypalInfo["displayName"] as? String
            //         paypalRequest.billingAgreementDescription = paypalInfo["billingAgreementDescription"] as? String
            //         dropInRequest.payPalRequest = paypalRequest
            //     // }
            // } else {
            //     dropInRequest.paypalDisabled = true
            // }

            if let applePayInfo = dict(for: "applePayRequest", in: call) {
                self.applePayInfo = applePayInfo
            } else {
                dropInRequest.applePayDisabled = true
            }

            guard let authorization = getAuthorization(call: call) else {
                returnAuthorizationMissingError(result: result)
                isHandlingResult = false
                return
            }

            self.authorization = authorization

            let dropInController = BTDropInController(
                authorization: authorization, request: dropInRequest
            ) { (controller, braintreeResult, error) in
                // --- MODIFIED DISMISSAL LOGIC ---
                // Dismiss the controller, then nil out the window to destroy it.
                controller.dismiss(animated: true) {
                    if braintreeResult?.isCanceled ?? false {
                        self.overlayWindow?.isHidden = true
                        self.overlayWindow = nil
                        return
                    }
                    if braintreeResult?.paymentMethodType != .applePay {
                        self.overlayWindow?.isHidden = true
                        self.overlayWindow = nil
                    }
                }
                self.handleResult(
                    result: braintreeResult, error: error, flutterResult: result,
                    deviceData: deviceData)
                self.isHandlingResult = false
            }

            guard let existingDropInController = dropInController else {
                result(
                    FlutterError(
                        code: "braintree_error",
                        message:
                            "BTDropInController not initialized (no API key or request specified?)",
                        details: nil))
                isHandlingResult = false
                return
            }

            // 4. Make the new window visible
            newWindow.makeKeyAndVisible()

            // 5. Present the Braintree controller from the new window's root VC
            blockerVC.present(existingDropInController, animated: true, completion: nil)

            // 6. Keep a reference to the window
            overlayWindow = newWindow
        }
    }

    private func setupApplePay(flutterResult: FlutterResult) {
        let paymentRequest = PKPaymentRequest()
        if let supportedNetworksValueArray = applePayInfo["supportedNetworks"] as? [Int] {
            paymentRequest.supportedNetworks = supportedNetworksValueArray.compactMap({ value in
                return PKPaymentNetwork.mapRequestedNetwork(rawValue: value)
            })
        }
        paymentRequest.merchantCapabilities = .capability3DS
        paymentRequest.countryCode = applePayInfo["countryCode"] as! String
        paymentRequest.currencyCode = applePayInfo["currencyCode"] as! String
        paymentRequest.merchantIdentifier = applePayInfo["merchantIdentifier"] as! String

        guard let paymentSummaryItems = makePaymentSummaryItems(from: applePayInfo) else {
            return
        }
        paymentRequest.paymentSummaryItems = paymentSummaryItems

        guard
            let applePayController = PKPaymentAuthorizationViewController(
                paymentRequest: paymentRequest)
        else {
            return
        }

        applePayController.delegate = self

        UIApplication.shared.keyWindow?.rootViewController?.present(
            applePayController, animated: true, completion: nil)
    }

    private func handleResult(
        result: BTDropInResult?, error: Error?, flutterResult: FlutterResult, deviceData: String?
    ) {
        if error != nil {
            returnBraintreeError(result: flutterResult, error: error!)
        } else if result?.isCanceled ?? false {
            flutterResult(nil)
        } else {
            if let result = result, result.paymentMethodType == .applePay {
                setupApplePay(flutterResult: flutterResult)
            } else {
                flutterResult([
                    "paymentMethodNonce": buildPaymentNonceDict(nonce: result?.paymentMethod),
                    "deviceData": deviceData,
                ])
            }
        }
    }

    private func handleApplePayResult(_ result: BTPaymentMethodNonce, flutterResult: FlutterResult)
    {
        flutterResult(["paymentMethodNonce": buildPaymentNonceDict(nonce: result)])
    }
}

// MARK: PKPaymentAuthorizationViewControllerDelegate
extension FlutterBraintreeDropInPlugin: PKPaymentAuthorizationViewControllerDelegate {
    public func paymentAuthorizationViewControllerDidFinish(
        _ controller: PKPaymentAuthorizationViewController
    ) {
        controller.dismiss(animated: true) {
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
        }
    }

    @available(iOS 11.0, *)
    public func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        guard let apiClient = BTAPIClient(authorization: authorization) else { return }
        let applePayClient = BTApplePayClient(apiClient: apiClient)

        applePayClient.tokenizeApplePay(payment) { (tokenizedPaymentMethod, error) in
            guard let paymentMethod = tokenizedPaymentMethod, error == nil else {
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }

            print(paymentMethod.nonce)
            self.handleApplePayResult(paymentMethod, flutterResult: self.completionBlock)
            completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        }
    }

    public func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment,
        completion: @escaping (PKPaymentAuthorizationStatus) -> Void
    ) {
        guard let apiClient = BTAPIClient(authorization: authorization) else { return }
        let applePayClient = BTApplePayClient(apiClient: apiClient)

        applePayClient.tokenizeApplePay(payment) { (tokenizedPaymentMethod, error) in
            guard let paymentMethod = tokenizedPaymentMethod, error == nil else {
                completion(.failure)
                return
            }

            print(paymentMethod.nonce)
            self.handleApplePayResult(paymentMethod, flutterResult: self.completionBlock)
            completion(.success)
        }
    }
}
