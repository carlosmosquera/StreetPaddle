import Firebase
import UserNotifications
import FirebaseAuth

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var unreadMessagesCount: Int = 0
    @Published var unreadAnnouncementsCount: Int = 0
    
    private var messagesListener: ListenerRegistration?
    private var announcementListener: ListenerRegistration?
    
    private init() {
        listenForUnreadMessages()
        listenForUnreadAnnouncements()
    }
    
    // Real-time listener for unread messages
    private func listenForUnreadMessages() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        print("Listening for unread messages for user: \(user.uid)")
        
        messagesListener = db.collection("groups")
            .whereField("members", arrayContains: user.uid)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching group messages: \(error.localizedDescription)")
                    return
                }
                
                var totalUnread = 0
                let groupChatIds = snapshot?.documents.map { $0.documentID } ?? []
                
                let dispatchGroup = DispatchGroup()
                
                groupChatIds.forEach { groupId in
                    dispatchGroup.enter()
                    self.fetchUnreadCount(for: groupId) { unreadCount in
                        totalUnread += unreadCount
                        dispatchGroup.leave()
                    }
                }
                
                dispatchGroup.notify(queue: .main) {
                    print("Unread messages count updated: \(totalUnread)")
                    self.unreadMessagesCount = totalUnread
                    self.updateAppBadge()
                }
            }
    }

    // Real-time listener for unread announcements
    private func listenForUnreadAnnouncements() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                let lastReadTimestamp = document.get("lastReadAnnouncementsTimestamp") as? Timestamp ?? Timestamp(date: Date(timeIntervalSince1970: 0))
                
                self.announcementListener = db.collection("publicMessages")
                    .whereField("timestamp", isGreaterThan: lastReadTimestamp)
                    .addSnapshotListener { snapshot, error in
                        if let error = error {
                            print("Error fetching public messages: \(error.localizedDescription)")
                            return
                        }
                        
                        DispatchQueue.main.async {
                            let unreadCount = snapshot?.documents.count ?? 0
                            print("Unread announcements count updated: \(unreadCount)")
                            self.unreadAnnouncementsCount = unreadCount
                            self.updateAppBadge()
                        }
                    }
            }
        }
    }
    
    // Fetch unread count for each group chat
    private func fetchUnreadCount(for groupChatId: String, completion: @escaping (Int) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        let userLastReadDocRef = db.collection("groups").document(groupChatId).collection("members").document(userId)
        
        userLastReadDocRef.getDocument { document, error in
            if let error = error {
                print("Error fetching last read timestamp: \(error)")
                completion(0)
                return
            }
            
            guard let document = document, let lastReadTimestamp = document.data()?["lastReadTimestamp"] as? Timestamp else {
                completion(0)
                return
            }
            
            db.collection("groups").document(groupChatId).collection("groupmessages")
                .whereField("timestamp", isGreaterThan: lastReadTimestamp)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching unread messages: \(error)")
                        completion(0)
                        return
                    }
                    
                    let unreadCount = snapshot?.documents.count ?? 0
                    print("Unread messages for \(groupChatId): \(unreadCount)")
                    completion(unreadCount)
                }
        }
    }
    
    // Update the app icon badge with the total unread count
    private func updateAppBadge() {
        let totalUnread = unreadMessagesCount + unreadAnnouncementsCount
        print("Updating app badge with total unread: \(totalUnread)")
        
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(totalUnread) { error in
                if let error = error {
                    print("Error setting badge count: \(error.localizedDescription)")
                } else {
                    print("Badge count successfully updated to: \(totalUnread)")
                }
            }
        }
    }
    
    // Stop listeners when necessary
    func stopListeners() {
        messagesListener?.remove()
        announcementListener?.remove()
    }
    
    func markAnnouncementsAsRead() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let currentTimestamp = Timestamp(date: Date())

        db.collection("users").document(userId).updateData([
            "lastReadAnnouncementsTimestamp": currentTimestamp
        ]) { error in
            if let error = error {
                print("Error marking announcements as read: \(error)")
            } else {
                DispatchQueue.main.async {
                    self.unreadAnnouncementsCount = 0
                    self.updateAppBadge()
                    print("Announcements marked as read.")
                }
            }
        }
    }

    func markMessagesAsRead(for groupId: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let currentTimestamp = Timestamp(date: Date())

        db.collection("groups").document(groupId).collection("members").document(userId).updateData([
            "lastReadTimestamp": currentTimestamp
        ]) { error in
            if let error = error {
                print("Error marking messages as read for group \(groupId): \(error)")
            } else {
                DispatchQueue.main.async {
                    self.unreadMessagesCount -= 1 // Adjust count based on the group's messages
                    self.updateAppBadge()
                    print("Messages marked as read for group \(groupId).")
                }
            }
        }
    }

}
