import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class ChatManager: ObservableObject {
    @Published var groupChats: [GroupChat] = []
    private var db = Firestore.firestore()
    private var userNamesCache: [String: String] = [:] // Cache to store user names

    func fetchGroupChats() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        db.collection("groups")
            .whereField("members", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching groups: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                var updatedGroupChats = [GroupChat]()

                let dispatchGroup = DispatchGroup()
                
                for document in documents {
                    var groupChat = try? document.data(as: GroupChat.self)
                    if let groupChatId = groupChat?.id {
                        dispatchGroup.enter()
                        self.fetchUnreadCount(for: groupChatId, userId: userId) { unreadCount in
                            groupChat?.unreadCount = unreadCount
                            updatedGroupChats.append(groupChat!)
                            dispatchGroup.leave()
                        }
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    self.groupChats = updatedGroupChats
                }
            }
    }

    private func fetchUnreadCount(for groupChatId: String, userId: String, completion: @escaping (Int) -> Void) {
        let userLastReadDocRef = db.collection("groups").document(groupChatId).collection("members").document(userId)
        
        userLastReadDocRef.getDocument { document, error in
            if let error = error {
                print("Error fetching last read timestamp: \(error)")
                completion(0)
                return
            }

            guard let document = document, let lastReadTimestamp = document.data()?["lastReadTimestamp"] as? Timestamp else {
                // If there's no last read timestamp, consider all messages as unread
                self.db.collection("groups").document(groupChatId).collection("groupmessages")
                    .getDocuments { snapshot, error in
                        if let error = error {
                            print("Error fetching messages: \(error)")
                            completion(0)
                            return
                        }
                        let unreadCount = snapshot?.documents.count ?? 0
                        completion(unreadCount)
                    }
                return
            }

            self.db.collection("groups").document(groupChatId).collection("groupmessages")
                .whereField("timestamp", isGreaterThan: lastReadTimestamp)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching unread messages: \(error)")
                        completion(0)
                        return
                    }

                    let unreadCount = snapshot?.documents.count ?? 0
                    completion(unreadCount)
                }
        }
    }
}
