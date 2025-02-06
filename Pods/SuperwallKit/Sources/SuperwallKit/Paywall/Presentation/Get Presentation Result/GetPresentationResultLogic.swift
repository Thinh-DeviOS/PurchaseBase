//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/03/2023.
//

import Foundation

enum GetPresentationResultLogic {
  /// Converts a ``TriggerResult`` to a ``PresentationResult``
  static func convertTriggerResult(_ triggerResult: InternalTriggerResult) -> PresentationResult {
    switch triggerResult {
    case .eventNotFound:
      return .eventNotFound
    case .holdout(let experiment):
      return .holdout(experiment)
    case .error:
      return .paywallNotAvailable
    case .noRuleMatch:
      return .noRuleMatch
    case .paywall(let experiment):
      return .paywall(experiment)
    }
  }
}
