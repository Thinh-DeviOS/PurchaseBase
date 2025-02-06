//
//  SuperwallService.swift
//  BaseIAP
//
//  Created by Nguyen Duc Thinh on 5/2/25.
//

import Foundation
import SuperwallKit

class SuperwallService {
    
    static let shared = SuperwallService()
    private let notifiCenter = NotificationCenter.default
    
    func configure(apiKey: String) {
        Superwall.configure(apiKey: apiKey)
        Superwall.shared.delegate = self
        
        #if DEBUG
        Superwall.shared.logLevel = .debug
        #else
        Superwall.shared.logLevel = .none
        #endif
    }
    
    func registerSuperwall(with placement: SuperwallPlacement, params: [SuperwallParameter: Any]? = nil, completion: (() -> Void)? = nil) {
        guard Superwall.shared.configurationStatus == .configured else { return }
        let handler = PaywallPresentationHandler()
        handler.onSkip { skipReason in
            switch skipReason {
            case .userIsSubscribed:
                self.notifiCenter.post(name: .superwallPurchaseDidUpdate, object: true)
            default: break
            }
            self.handleEvent(log: "Log-Superwall Handler on Skip: \(skipReason)", completion: completion)
        }
        handler.onError { error in
            self.handleEvent(log: "Log-Superwall Handler Error: \(error.localizedDescription)", completion: completion)
        }
        handler.onPresent { _ in
            self.handleEvent(log: "Log-Superwall on Present", completion: completion)
        }
        handler.onDismiss { _ in
            self.handleEvent(log: "Log-Superwall on Dismiss", completion: completion)
        }
        
        // register
        var resultParams: [String: Any]?
        if let params, !params.isEmpty {
            resultParams = [:]
            for param in params {
                resultParams?[param.key.rawValue] = param.value
            }
        }
        
        Superwall.shared.register(event: placement.rawValue, params: resultParams, handler: handler)
    }
    
    private func handleEvent(log: String, completion: (() -> Void)?) {
        Logger.log(log)
        DispatchQueue.main.async {
            completion?()
        }
    }
}

// MARK: - Superwall Delegate

extension SuperwallService: SuperwallDelegate {
    func subscriptionStatusDidChange(to newValue: SubscriptionStatus) {
        switch newValue {
        case .active:
            notifiCenter.post(name: .superwallPurchaseDidUpdate, object: true)
        case .inactive:
            notifiCenter.post(name: .superwallPurchaseDidUpdate, object: false)
        case .unknown:
            break
        }
    }
    
    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        switch eventInfo.event {
        case .transactionRestore(restoreType: let trans, paywallInfo: let info):
            Logger.logWithTime("Log-Superwall transaction restore: \(trans), paywallInfo: \(info)")
            self.notifiCenter.post(name: .superwallPurchaseDidUpdate, object: true)
            break
        case .transactionComplete(transaction: let trans, product: let product, paywallInfo: let info):
            Logger.logWithTime("Log-Superwall transaction completion: \(String(describing: trans)), product: \(product), paywallInfo: \(info)")
            self.updateInAppTracking(with: trans, product: product)
            break
        default: break
        }
        Logger.logWithTime("Log-Superwall event info: \(eventInfo.event.description)")
    }
    
    func handleCustomPaywallAction(withName name: String) {
        Logger.logWithTime("Log-Superwall event nameL: \(name)")
        switch name.lowercased() {
        case TermService.term, TermService.terms, TermService.termOfService, TermService.termsOfService:
            presentSuperwallWebViewController(title: "Terms of Service", webUrlString: "") // Changed in Constants
        case PolicyService.policy, PolicyService.privacy, PolicyService.privacyPolicy:
            presentSuperwallWebViewController(title: "Privacy Policy", webUrlString: "") // Changed in Constants
        default: break
        }
    }
    
    func willPresentPaywall(withInfo paywallInfo: PaywallInfo) {}
    func didPresentPaywall(withInfo paywallInfo: PaywallInfo) {}
    func willDismissPaywall(withInfo paywallInfo: PaywallInfo) {}
    func didDismissPaywall(withInfo paywallInfo: PaywallInfo) {}
    func paywallWillOpenURL(url: URL) {}
    func paywallWillOpenDeepLink(url: URL) {}
    func handleLog(level: String, scope: String, message: String?, info: [String : Any]?, error: (any Error)?) {}
    
    // MARK: - Privacy Function
    
    private func presentSuperwallWebViewController(title: String, webUrlString: String) {
        DispatchQueue.main.async {
            guard let topVC = UIApplication.topViewController() else { return }
            let controller = SuperwallWebviewController()
            controller.titleText = title
            controller.webUrl = URL(string: webUrlString)
            topVC.present(controller, animated: true)
        }
    }
    
    private func updateInAppTracking(with transaction: StoreTransaction?, product: StoreProduct) {
        guard let transactionId = transaction?.originalTransactionIdentifier else { return }
        let currencyCode = product.currencyCode
        let productId = product.productIdentifier
        let price = NSDecimalNumber(decimal: product.price).doubleValue
        let regionIdentifier = product.regionCode
        let purchaseDate = transaction?.transactionDate
        if product.subscriptionPeriod == nil {
            AdjustManager.shared.loggerInAppPurchase(
                transactionId: transactionId,
                price: price,
                productId: productId,
                currency: currencyCode,
                region: regionIdentifier,
                transactionDate: transDate
            )
        } else {
            AdjustManager.shared.loggerInAppSubscription(
                transactionId: transactionId,
                price: price,
                productId: productId,
                currency: currencyCode,
                region: regionIdentifier,
                transactionDate: transDate
            )
        }
    }
}

struct TermService {
    static let term = "term"
    static let terms = "terms"
    static let termOfService = "term of service"
    static let termsOfService = "terms of service"
}

struct PolicyService {
    static let policy = "policy"
    static let privacy = "privacy"
    static let privacyPolicy = "privacy Policy"
}
