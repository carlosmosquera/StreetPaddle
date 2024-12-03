import Foundation
import StoreKit

// Aliases
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

class StoreVM: ObservableObject {
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionGroupStatus: RenewalState?
    
    private let productionURL = "https://buy.itunes.apple.com/verifyReceipt"
    private let sandboxURL = "https://sandbox.itunes.apple.com/verifyReceipt"
    
    private let productIds: [String] = ["subscription.yearly"]
    var updateListenerTask: Task<Void, Error>? = nil
    
    init() {
        // Start a transaction listener as close to app launch as possible
        updateListenerTask = listenForTransactions()
        
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
            await checkAndValidateReceipt() // Validate receipt during initialization
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
    
    // Function to validate receipts
    func validateReceipt() async throws -> Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            print("No receipt found.")
            return false
        }
        
        let receiptBase64 = receiptData.base64EncodedString()
        
        // Create a JSON object for the request
        let requestBody: [String: Any] = ["receipt-data": receiptBase64]
        guard let requestData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("Failed to serialize receipt data.")
            return false
        }
        
        do {
            // Validate against the production environment
            try await validateReceipt(with: requestData, url: productionURL)
            print("Receipt validated with production environment.")
            return true
        } catch let error as NSError where error.code == 21007 {
            // Error 21007: Sandbox receipt used in production
            print("Sandbox receipt detected. Retrying with sandbox environment.")
            do {
                try await validateReceipt(with: requestData, url: sandboxURL)
                print("Receipt validated with sandbox environment.")
                return true
            } catch {
                print("Failed to validate receipt with sandbox environment: \(error)")
                throw error
            }
        } catch {
            print("Failed to validate receipt with production environment: \(error)")
            throw error
        }
    }
    
    // Helper function to validate receipt with a specific URL
    private func validateReceipt(with requestData: Data, url: String) async throws {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "StoreVM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }
        
        guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "StoreVM", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }
        
        if let status = jsonResponse["status"] as? Int, status != 0 {
            throw NSError(domain: "StoreVM", code: status, userInfo: [NSLocalizedDescriptionKey: "Receipt validation failed with status \(status)"])
        }
    }
    
    // Example usage of receipt validation
    @MainActor
    func checkAndValidateReceipt() async {
        do {
            let isValid = try await validateReceipt()
            print("Receipt validation result: \(isValid ? "Valid" : "Invalid")")
        } catch {
            print("Error during receipt validation: \(error)")
        }
    }
}

// Error for failed verification
public enum StoreError: Error {
    case failedVerification
}
