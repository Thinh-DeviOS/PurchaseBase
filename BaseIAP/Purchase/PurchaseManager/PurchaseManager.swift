//
//  PurchaseManager.swift
//  BaseIAP
//
//  Created by Nguyen Duc Thinh on 5/2/25.
//

import Foundation
import Combine

class UserDefaultsKey {
    static let appPurchasePulishedKey = "AppPurchasePulishedKey"
}

class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    private let notifiCenter = NotificationCenter.default
    private let userDefault = UserDefaults.standard
    private lazy var cancellables = Set<AnyCancellable>()
    private lazy var notifiNames: [Notification.Name] = [.revenueCastPurchaseDidUpdate, .superwallPurchaseDidUpdate]
   
    @Published private(set) var isPurchase: Bool = UserDefaults.standard.bool(forKey: UserDefaultsKey.appPurchasePulishedKey) {
        didSet {
            userDefault.set(isPurchase, forKey: UserDefaultsKey.appPurchasePulishedKey)
        }
    }
    
    func configure() {
        let elementId = "ElementId" // Changed in ConfigHelper
        let revenueApi = "RevenueApi" // Changed in ConfigHelper
        let superwallApi = "superwallApi" // Changed in ConfigHelper
        
        RevenueCastService.shared.configure(apiKey: revenueApi, entitId: elementId, userId: nil)
        SuperwallService.shared.configure(apiKey: superwallApi)
        notifiPurchaseChanged()
        updateInAppTracking()
    }
    
    func notifiPurchaseChanged() {
        Publishers.MergeMany(notifiNames.map { notifiCenter.publisher(for: $0) })
            .map { $0.object as? Bool ?? false }
            .sink { isPurchase in
                self.isPurchase = isPurchase
            }
            .store(in: &cancellables)
    }
    
    func updateInAppTracking() {
        notifiCenter.publisher(for: .updateInAppTracking)
            .map { $0.object as? LoggerInAppPurchase }
            .sink { logger in
                // update In App Tracking
                print("\(String(describing: logger))")
            }
            .store(in: &cancellables)
    }
}
