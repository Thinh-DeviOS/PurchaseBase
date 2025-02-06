//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/05/2023.
//
// swiftlint:disable trailing_closure

import Foundation

extension PaywallRequestManager {
  func addProducts(
    to paywall: Paywall,
    request: PaywallRequest
  ) async throws -> Paywall {
    var paywall = paywall

    paywall = await trackProductsLoadStart(
      paywall: paywall,
      request: request
    )
    paywall = try await getProducts(
      for: paywall,
      request: request
    )
    paywall = await trackProductsLoadFinish(
      paywall: paywall,
      event: request.eventData
    )

    return paywall
  }

  private func getProducts(for paywall: Paywall, request: PaywallRequest) async throws -> Paywall {
    var paywall = paywall

    do {
      let result = try await storeKitManager.getProducts(
        forPaywall: paywall,
        event: request.eventData,
        substituting: request.overrides.products
      )

      paywall.productItems = result.productItems

      let outcome = await PaywallLogic.getVariablesAndFreeTrial(
        productItems: result.productItems,
        productsById: result.productsById,
        isFreeTrialAvailableOverride: request.overrides.isFreeTrial,
        isFreeTrialAvailable: { [weak self] product in
          guard let self = self else { return false }
          return await self.factory.isFreeTrialAvailable(for: product)
        }
      )
      paywall.productVariables = outcome.productVariables
      paywall.isFreeTrialAvailable = outcome.isFreeTrialAvailable

      return paywall
    } catch {
      paywall.productsLoadingInfo.failAt = Date()
      let paywallInfo = paywall.getInfo(fromEvent: request.eventData)
      await trackProductLoadFail(
        paywallInfo: paywallInfo,
        event: request.eventData,
        error: error
      )
      throw error
    }
  }

  // MARK: - Analytics
  private func trackProductsLoadStart(paywall: Paywall, request: PaywallRequest) async -> Paywall {
    var paywall = paywall
    paywall.productsLoadingInfo.startAt = Date()
    let paywallInfo = paywall.getInfo(fromEvent: request.eventData)
    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .start,
      paywallInfo: paywallInfo,
      eventData: request.eventData
    )
    await Superwall.shared.track(productLoadEvent)

    return paywall
  }

  private func trackProductLoadFail(
    paywallInfo: PaywallInfo,
    event: EventData?,
    error: Error
  ) async {
    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .fail(error),
      paywallInfo: paywallInfo,
      eventData: event
    )
    await Superwall.shared.track(productLoadEvent)
  }

  private func trackProductsLoadFinish(
    paywall: Paywall,
    event: EventData?
  ) async -> Paywall {
    var paywall = paywall
    paywall.productsLoadingInfo.endAt = Date()
    let paywallInfo = paywall.getInfo(fromEvent: event)
    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .complete,
      paywallInfo: paywallInfo,
      eventData: event
    )
    await Superwall.shared.track(productLoadEvent)

    return paywall
  }
}
