//
//  Package+title.swift
//  BaseIAP
//
//  Created by Nguyen Duc Thinh on 5/2/25.
//

import Foundation
import RevenueCat

extension Package {
    var titleLocaltization: String {
        guard let period = storeProduct.subscriptionPeriod else { return "Lifetime" }
        
        let number = period.value
        switch storeProduct.subscriptionPeriod?.unit {
        case .day:
            if number == 7 {
                return "Weekly"
            } else {
                return "Daily"
            }
        case .week: return "Weekly"
        case .month: return "Month"
        case .year: return "Yearly"
        default: return "Lifetime"
        }
    }
    
    var price: String {
        switch storeProduct.subscriptionPeriod?.unit {
        case .day: return "\(storeProduct.localizedPriceString.dropLast())"
        case .week: return "\(storeProduct.localizedPriceString.dropLast())"
        case .month: return "\(storeProduct.localizedPriceString.dropLast())"
        case .year: return "\(storeProduct.localizedPriceString.dropLast())"
        default: return ""
        }
    }
}
