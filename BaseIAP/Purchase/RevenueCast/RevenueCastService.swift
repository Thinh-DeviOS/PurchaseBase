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
    
    func purchase(_ package: RevenueCat.Package, entitId: String) async -> (Bool, RevenueCastError?) {
        guard !isWaiting else { return (false, .waiting) }
        return await withCheckedContinuation { continuation in
            isWaiting = true
            Purchases.shared.purchase(package: package) { store, info, error, _ in
                Task {
                    let (grant, error) = await self.resultsHandler(info: info, package: package, store: store, error: error)
                    continuation.resume(returning: (grant, error))
                }
            }
        }
    }
    
    func restorePurchases(entitId: String) async -> (Bool, RevenueCastError?) {
        guard !isWaiting else { return (false, .waiting) }
        return await withCheckedContinuation { continuation in
            isWaiting = true
            Purchases.shared.restorePurchases { info, error in
                Task {
                    let (grant, error) = await self.resultsHandler(info: info, package: nil, store: nil, error: error)
                    continuation.resume(returning: (grant, error))
                }
            }
        }
    }
    
    func getPackages(_ offeringIdentifier: String) async -> ([Package], RevenueCastError?) {
        return await withCheckedContinuation { continuation in
            Purchases.shared.getOfferings { offering, error in
                if let error {
                    continuation.resume(returning: ([], .error(error)))
                } else {
                    let packages: [Package] = offering?.offering(identifier: offeringIdentifier)?.availablePackages ?? []
                    continuation.resume(returning: (packages, nil))
                }
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
    
    private func resultsHandler(info: CustomerInfo?, package: RevenueCat.Package?, store: StoreTransaction?, error: PublicError?) async -> (Bool, RevenueCastError?) {
        self.isWaiting = false
        if let error {
            return (false, .error(error))
        } else
        if let info, info.entitlements.all[entitId]?.isActive == true {
            if let store, let package {
                updateInAppTracking(with: store, package: package)
            }
            return (true, nil)
        } else {
            return (false, nil)
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
            let logger = LoggerInAppPurchase(
                packagetype: .lifetime,
                transactionId: transactionId,
                productId: productId,
                price: price,
                currency: currencyCode,
                region: regionIdentifier,
                transactionDate: transDate
            )
            notifiCenter.post(name: .updateInAppTracking, object: logger)
        } else {
            let logger = LoggerInAppPurchase(
                packagetype: .annual,
                transactionId: transactionId,
                productId: productId,
                price: price,
                currency: currencyCode,
                region: regionIdentifier,
                transactionDate: transDate
            )
            notifiCenter.post(name: .updateInAppTracking, object: logger)
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
