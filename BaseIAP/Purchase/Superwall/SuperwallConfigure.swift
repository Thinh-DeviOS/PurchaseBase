//
//  SuperwallConfigure.swift
//  BaseIAP
//
//  Created by Nguyen Duc Thinh on 5/2/25.
//

import Foundation

enum SuperwallPlacement: String {
    case splash_first_end
    case splash_seconds_end
    case onboarding_first_end
    case onboarding_seconds_end
    case language_first_end
    case language_seconds_end
    case language_settings
}

enum SuperwallParameter: String {
    case user_id
}
