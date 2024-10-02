import SwiftUI
import Combine

class NotificationManager: ObservableObject {
    @Published var publicMessagesNotificationCount: Int = 0

    func resetPublicMessagesNotificationCount() {
        publicMessagesNotificationCount = 0
    }
    
    func incrementPublicMessagesNotificationCount() {
        publicMessagesNotificationCount += 1
    }
    
    // Add any additional notification handling logic as needed
}
