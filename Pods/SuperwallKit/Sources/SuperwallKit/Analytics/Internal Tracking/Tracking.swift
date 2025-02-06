//
//  File.swift
//  
//
//  Created by Jake Mor on 8/16/21.
//

import Foundation
import Combine

extension Superwall {
  /// Tracks an analytical event by sending it to the server and, for internal Superwall events, the delegate.
  ///
  /// - Parameters:
  ///   - trackableEvent: The event you want to track.
  ///   - audienceFilterParams: Any extra non-Superwall parameters that you want to track.
	@discardableResult
  func track(_ event: Trackable) async -> TrackingResult {
    // Get parameters to be sent to the delegate and stored in an event.
    let eventCreatedAt = Date()
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: dependencyContainer.appSessionManager.appSession.id
    )

    // For a trackable superwall event, send params to delegate
    if let trackedEvent = event as? TrackableSuperwallEvent {
      let info = SuperwallEventInfo(
        event: trackedEvent.superwallEvent,
        params: parameters.delegateParams
      )

      await dependencyContainer.delegateAdapter.handleSuperwallEvent(withInfo: info)

      Logger.debug(
        logLevel: .debug,
        scope: .events,
        message: "Logged Event",
        info: parameters.audienceFilterParams
      )
    }

    let eventData = EventData(
      name: event.rawName,
      parameters: JSON(parameters.audienceFilterParams),
      createdAt: eventCreatedAt
    )

    // If config doesn't exist yet we rely on previous saved feature flag
    // to determine whether to disable verbose events.
    let existingDisableVerboseEvents = dependencyContainer.configManager.config?.featureFlags.disableVerboseEvents
    let previousDisableVerboseEvents = dependencyContainer.storage.get(DisableVerboseEvents.self)

    let verboseEvents = existingDisableVerboseEvents ?? previousDisableVerboseEvents

    if TrackingLogic.isNotDisabledVerboseEvent(
      event,
      disableVerboseEvents: verboseEvents,
      isSandbox: dependencyContainer.makeIsSandbox()
    ) {
      await dependencyContainer.eventsQueue.enqueue(
        data: eventData.jsonData,
        from: event
      )
    }
    dependencyContainer.storage.coreDataManager.saveEventData(eventData)

    if event.canImplicitlyTriggerPaywall {
      Task.detached { [weak self] in
        await self?.handleImplicitTrigger(
          forEvent: event,
          withData: eventData
        )
      }
		}

    let result = TrackingResult(
      data: eventData,
      parameters: parameters
    )
		return result
  }

  /// Attemps to implicitly trigger a paywall for a given analytical event.
  ///
  ///  - Parameters:
  ///     - event: The tracked event.
  ///     - eventData: The event data that could trigger a paywall.
  @MainActor
  func handleImplicitTrigger(
    forEvent event: Trackable,
    withData eventData: EventData
  ) async {
    // Assign the current register task while capturing the previous one.
    previousRegisterTask = Task { [weak self, previousRegisterTask] in
      // Wait until the previous register task is finished before continuing.
      await previousRegisterTask?.value

      await self?.internallyHandleImplicitTrigger(
        forEvent: event,
        withData: eventData
      )
    }
  }

  @MainActor
  private func internallyHandleImplicitTrigger(
    forEvent event: Trackable,
    withData eventData: EventData
  ) async {
    let presentationInfo: PresentationInfo = .implicitTrigger(eventData)

    var request = dependencyContainer.makePresentationRequest(
      presentationInfo,
      isPaywallPresented: isPaywallPresented,
      type: .presentation
    )

    do {
      try await waitForSubsStatusAndConfig(request, paywallStatePublisher: nil)
    } catch {
      return logErrors(from: request, error)
    }

    let triggeringOutcome = TrackingLogic.canTriggerPaywall(
      event,
      triggers: Set(dependencyContainer.configManager.triggersByEventName.keys),
      paywallViewController: paywallViewController
    )

    var statePublisher = PassthroughSubject<PaywallState, Never>()

    switch triggeringOutcome {
    case .deepLinkTrigger:
      await dismiss()
    case .closePaywallThenTriggerPaywall:
      guard let lastPresentationItems = presentationItems.last else {
        return
      }

      // Make sure the result of presenting will be a paywall, otherwise do not proceed.
      // This is important to stop the paywall from being skipped and firing the feature
      // block when it shouldn't. This has to be done only to those triggers that reassign
      // the statePublisher. Others like app_launch are fine to skip and users are relying
      // on paywallPresentationRequest for those.
      let presentationResult = await internallyGetPresentationResult(
        forEvent: event,
        requestType: .handleImplicitTrigger
      )
      guard case .paywall = presentationResult else {
        return
      }
      await dismissForNextPaywall()

      request.paywallOverrides = PaywallOverrides(featureGatingBehavior: lastPresentationItems.featureGatingBehavior)
      statePublisher = lastPresentationItems.statePublisher
    case .triggerPaywall:
      break
    case .dontTriggerPaywall:
      return
    }

    request.flags.isPaywallPresented = isPaywallPresented

    await internallyPresent(request, statePublisher)
  }
}
