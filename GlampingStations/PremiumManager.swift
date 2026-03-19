//
//  PremiumManager.swift
//  GlampingStations
//

import Foundation
import StoreKit

@MainActor
class PremiumManager: ObservableObject {

    static let shared = PremiumManager()

    // MARK: - Notifications
    static let premiumStatusChanged = Notification.Name("premiumStatusChanged")

    // MARK: - Constants
    static let productID = "com.scottkriss.glampingstations.premium"
    static let freeFavoritesLimit = 5
    private static let purchasedKey = "glampingPremiumPurchased"
    private static let demoModeKey  = "premiumDemoMode"

    // MARK: - State

    private(set) var isPurchased: Bool = false

    var isDemoModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.demoModeKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.demoModeKey)
            NotificationCenter.default.post(name: Self.premiumStatusChanged, object: nil)
        }
    }

    /// True if user has real purchase OR demo mode is on.
    var isPremium: Bool {
        isPurchased || isDemoModeEnabled
    }

    // MARK: - Init

    private init() {
        isPurchased = UserDefaults.standard.bool(forKey: Self.purchasedKey)
    }

    // MARK: - Favorite Limit Check

    /// Total favorites across both station types.
    var totalFavoriteCount: Int {
        let gas  = StationsController.shared.stationArray.filter { $0.favorite }.count
        let dump = DumpStationsController.shared.dumpStationArray.filter { $0.favorite }.count
        return gas + dump
    }

    /// Whether the user can add another favorite right now.
    var canAddFavorite: Bool {
        isPremium || totalFavoriteCount < Self.freeFavoritesLimit
    }

    // MARK: - StoreKit 2

    /// Starts the background transaction listener. Call once on app launch.
    func startTransactionListener() {
        Task {
            for await result in Transaction.updates {
                await handle(transactionResult: result)
            }
        }
    }

    /// Restores any previous purchases.
    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            await handle(transactionResult: result)
        }
    }

    /// Triggers the StoreKit purchase sheet for the premium product.
    /// Returns true if purchase succeeded.
    @discardableResult
    func purchase() async throws -> Bool {
        let products = try await Product.products(for: [Self.productID])
        guard let product = products.first else {
            print("PremiumManager: product not found in App Store")
            return false
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            await handle(transactionResult: verification)
            return isPurchased
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Private

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        switch transactionResult {
        case .unverified:
            break
        case .verified(let transaction):
            if transaction.productID == Self.productID && transaction.revocationDate == nil {
                markPurchased()
            }
            await transaction.finish()
        }
    }

    private func markPurchased() {
        isPurchased = true
        UserDefaults.standard.set(true, forKey: Self.purchasedKey)
        NotificationCenter.default.post(name: Self.premiumStatusChanged, object: nil)
    }
}
