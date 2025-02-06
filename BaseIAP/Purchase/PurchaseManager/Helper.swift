//
//  Helper.swift
//  BaseIAP
//
//  Created by Nguyen Duc Thinh on 5/2/25.
//

import UIKit

extension Notification.Name {
    static let revenueCastPurchaseDidUpdate = Notification.Name("revenue cast purchase did update")
    static let superwallPurchaseDidUpdate = Notification.Name("revenue cast purchase did update")
}

// MARK: -  UIApplication

extension UIApplication {
    static func topViewController(_ controller: UIViewController? = UIApplication.lastWindow?.rootViewController) -> UIViewController? {
        guard let controller else { return nil }
        if let navController = controller as? UINavigationController {
            return topViewController(navController.visibleViewController)
        } else
        if let tabBarController = controller.tabBarController {
            return topViewController(tabBarController.selectedViewController)
        } else
        if let presentVC = controller.presentedViewController {
            return topViewController(presentVC.presentedViewController)
        } else {
            return controller
        }
    }
    
    static var lastWindow: UIWindow? {
        if #available(iOS 15.0, *) {
            return (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.last
        } else {
            return UIApplication.shared.windows.last
        }
    }
}

// MARK: - Logger

struct Logger {
    static func log(_ mess: Any, name: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let last = name.components(separatedBy: "/").last ?? ""
        print("[DEBUG] - [fileName: \(last) - function: \(function) - line: \(line)] - message: \(String(describing: mess))")
        #endif
    }
    
    static func logWithTime(_ mess: Any, name: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let date = Date()
        let formater = DateFormatter()
        formater.dateFormat = "hh:mm:ss"
        let last = name.components(separatedBy: "/").last ?? ""
        print("[DEBUG] - [\(formater.string(from: date))] - [fileName: \(last) - function: \(function) - line: \(line)] - message: \(String(describing: mess))")
        #endif
    }
    static func logFuncWithTime(_ mess: Any, function name: String = #function) {
        #if DEBUG
        let date = Date()
        let formater = DateFormatter()
        formater.dateFormat = "hh:mm:ss"
        print("[DEBUG] - [\(formater.string(from: date))] - [function: \(name)] - message: \(String(describing: mess))")
        #endif
    }
}

// MARK: - Locale

extension Locale {
    static var regionIdentifier: String? {
        if #available(iOS 16.0, *) {
            return current.region?.identifier
        } else {
            return current.regionCode
        }
    }
}
