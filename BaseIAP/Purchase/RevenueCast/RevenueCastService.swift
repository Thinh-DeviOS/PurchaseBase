//
//  RevenueCastService.swift
//  BaseIAP
//
//  Created by Nguyen Duc Thinh on 5/2/25.
//

import Foundation
import RevenueCat

class RevenueCastService {
    static let shared = RevenueCastService()
    typealias Completion = (Bool, RevenueCastError?) -> Void
    
    private let notifiCenter = NotificationCenter.default
    private let userDefaultName: String = ".revenueCat" // To do changed default name
    private lazy var userDefault: UserDefaults = .init(suiteName: userDefaultName) ?? .standard
    var entitId: String = ""
    
    private var isWaiting = false // Waiting purchase or restore response
    
    func configure(apiKey: String, entitId: String?, userId: String?) {
        if let entitId { self.entitId = entitId }
        config(apiKey: apiKey, entitId: entitId, userId: userId)
        
        // validate user
        guard !isWaiting else {
            notifiCenter.post(name: .revenueCastPurchaseDidUpdate, object: false)
            return
        }
        isWaiting = true
        getCustomerInfo(entitId: entitId)
    }
    
    func purchase(_ package: RevenueCat.Package, entitId: String, completion: @escaping Completion) {
        checkIsWaiting(completion: completion)
        Purchases.shared.purchase(package: package) { store, info, error, _ in
            self.resultsHandler(info: info, package: nil, store: store, error: error, completion: completion)
        }
    }
    
    func restorePurchases(entitId: String, completion: @escaping Completion) {
        checkIsWaiting(completion: completion)
        Purchases.shared.restorePurchases { info, error in
            self.resultsHandler(info: info, package: nil, store: nil, error: error, completion: completion)
        }
    }
    
    func getPackages(_ offeringIdentifier: String, completion: @escaping ([Package], RevenueCastError?) -> Void) {
        Purchases.shared.getOfferings { offering, error in
            if let error {
                completion([], .error(error))
            } else {
                let packages: [Package] = offering?.offering(identifier: offeringIdentifier)?.availablePackages ?? []
                completion(packages, nil)
            }
        }
    }
}

// MARK: - Support Privacy Function

extension RevenueCastService {
    private func config(apiKey: String, entitId: String?, userId: String?) {
        let configBuild = Configuration.Builder(withAPIKey: apiKey)
            .with(appUserID: userId)
            .with(userDefaults: userDefault)
            .build()
        
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .verbose
        #endif
        
        // configure
        Purchases.configure(with: configBuild)
    }
    
    private func getCustomerInfo(entitId: String?) {
        Purchases.shared.getCustomerInfo { [weak self] info, error in
            guard let self else { return }
            isWaiting = false
            if let error {
                Logger.logFuncWithTime("Error validate user: /n\(error.localizedDescription)")
                notifiCenter.post(name: .revenueCastPurchaseDidUpdate, object: false)
            } else
            if let info, let entitId, info.entitlements.all[entitId]?.isActive == true {
                notifiCenter.post(name: .revenueCastPurchaseDidUpdate, object: true)
            } else {
                notifiCenter.post(name: .revenueCastPurchaseDidUpdate, object: false)
            }
        }
    }
    
    private func checkIsWaiting(completion: @escaping Completion) {
        guard !isWaiting else {
            completion(false, .waiting)
            return
        }
        isWaiting = true
    }
    
    private func resultsHandler(info: CustomerInfo?, package: RevenueCat.Package?, store: StoreTransaction?, error: PublicError?, completion: @escaping Completion) {
        self.isWaiting = false
        if let error {
            completion(false, .error(error))
        } else
        if let info, info.entitlements.all[entitId]?.isActive == true {
            if let store, let package {
                updateInAppTracking(with: store, package: package)
            }
            completion(true, nil)
        } else {
            completion(false, nil)
        }
    }
    
    private func updateInAppTracking(with transaction: StoreTransaction?, package: Package) {
        guard let transactionId = transaction?.transactionIdentifier,
             let currencyCode = package.storeProduct.currencyCode
        else { return }
        
        let productId = package.storeProduct.productIdentifier
        let price = package.storeProduct.priceDecimalNumber.doubleValue
        let regionIdentifier = Locale.regionIdentifier
        let transDate = transaction?.purchaseDate
        
        if package.packageType == .lifetime {
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

// MARK: -  Revenue Cas tError
enum RevenueCastError: Error,CustomDebugStringConvertible {
    case waiting, error(PublicError)
    var debugDescription: String {
        switch self {
        case .waiting:
            return "Waiting purchase or restore"
        case .error(let publicError):
            return publicError.localizedDescription
        }
    }
}
