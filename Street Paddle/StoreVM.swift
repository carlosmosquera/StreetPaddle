import Foundation
import StoreKit

// Aliases
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

class StoreVM: ObservableObject {
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionGroupStatus: RenewalState?

    private let productIds: [String] = ["subscription.yearly"]
    var updateListenerTask: Task<Void, Error>? = nil

    init() {
        // Start a transaction listener as close to app launch as possible
        updateListenerTask = listenForTransactions()

        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // Listen for transactions
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    // Deliver products to the user
                    await self.updateCustomerProductStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }

    // Request the products
    @MainActor
    func requestProducts() async {
        do {
            // Request products from the App Store using the product IDs
            subscriptions = try await Product.products(for: productIds)
            print(subscriptions)
        } catch {
            print("Failed product request from App Store server: \(error)")
        }
    }

    // Purchase the product
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Check whether the transaction is verified
            let transaction = try checkVerified(verification)

            // Deliver content to the user
            await updateCustomerProductStatus()

            // Always finish a transaction
            await transaction.finish()

            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }

    // Restore purchases
    @MainActor
    func restorePurchases() async {
        // Restore purchases by updating current entitlements
        await updateCustomerProductStatus()
        print("Purchases restored successfully.")
    }

    // Check if the transaction is verified
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit verification
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification
            throw StoreError.failedVerification
        case .verified(let safe):
            // The result is verified; return the unwrapped value
            return safe
        }
    }

    // Update customer product status
    @MainActor
    func updateCustomerProductStatus() async {
        for await result in Transaction.currentEntitlements {
            do {
                // Check whether the transaction is verified
                let transaction = try checkVerified(result)

                switch transaction.productType {
                case .autoRenewable:
                    if let subscription = subscriptions.first(where: { $0.id == transaction.productID }) {
                        purchasedSubscriptions.append(subscription)
                    }
                default:
                    break
                }
                // Always finish a transaction
                await transaction.finish()
            } catch {
                print("Failed updating products")
            }
        }
    }
}

// Error for failed verification
public enum StoreError: Error {
    case failedVerification
}
