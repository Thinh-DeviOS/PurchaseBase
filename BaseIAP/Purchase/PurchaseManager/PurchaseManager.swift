//
//  PurchaseManager.swift
//  BaseIAP
//
//  Created by Nguyen Duc Thinh on 5/2/25.
//

import Foundation
import Combine

class PurchaseManager {
    static let shared = PurchaseManager()
    
    private let notifiCenter = NotificationCenter.default
    private lazy var cancellables = Set<AnyCancellable>()
    private lazy var notifiNames: [Notification.Name] = [.revenueCastPurchaseDidUpdate, .superwallPurchaseDidUpdate]
   
    var isPurchase: Bool {
        // get isAppPurchasePublished
        return false
    }
    
    func configure() {
        let elementId = "ElementId" // Changed in ConfigHelper
        let revenueApi = "RevenueApi" // Changed in ConfigHelper
        let superwallApi = "superwallApi" // Changed in ConfigHelper
        
        RevenueCastService.shared.configure(apiKey: revenueApi, entitId: elementId, userId: nil)
        SuperwallService.shared.configure(apiKey: superwallApi)
        notifiPurchaseChanged()
    }
    
    func notifiPurchaseChanged() {
        Publishers.MergeMany(notifiNames.map { notifiCenter.publisher(for: $0) })
            .map { $0.object as? Bool }
            .sink { [weak self] isPurchase in
                guard let self else { return }
                //                if UserDefaultsHelper.shared.isAppPurchasePulished != isPurchase {
                //                    UserDefaultsHelper.shared.isAppPurchasePulished = isPurchase
                //                }
            }
            .store(in: &cancellables)
    }
}
