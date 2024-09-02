import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class ChatManager: ObservableObject {
    @Published var groupChats: [GroupChat] = []
    @Published var totalUnreadCount: Int = 0
    private var db = Firestore.firestore()
    private var userNamesCache: [String: String] = [:] // Cache to store user names

    func fetchGroupChats() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        db.collection("groups")
            .whereField("members", arrayContains: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching groups: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                var updatedGroupChats = [GroupChat]()
                var newTotalUnreadCount = 0
                var directChatGroups: [String: GroupChat] = [:] // Store direct chats by recipient name

                let dispatchGroup = DispatchGroup()

                for document in documents {
                    var groupChat = try? document.data(as: GroupChat.self)
                    if let groupChatId = groupChat?.id {
                        dispatchGroup.enter()
                        self.fetchUnreadCount(for: groupChatId, userId: userId) { unreadCount in
                            groupChat?.unreadCount = unreadCount

                            if let groupChat = groupChat, groupChat.members.count == 2 {
                                let recipientName = self.getDirectChatRecipientName(for: groupChat, currentUserID: userId)
                                if let existingChat = directChatGroups[recipientName] {
                                    // Merge chats if a direct chat with the same recipient exists
                                    self.mergeGroupChats(existingChat: existingChat, newChat: groupChat) { mergedChat in
                                        directChatGroups[recipientName] = mergedChat
                                    }
                                } else {
                                    directChatGroups[recipientName] = groupChat
                                }
                            } else if let groupChat = groupChat {
                                updatedGroupChats.append(groupChat)
                            }

                            dispatchGroup.leave()
                        }
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    // Add merged direct chats to the final list
                    updatedGroupChats.append(contentsOf: directChatGroups.values)
                    self.groupChats = updatedGroupChats
                    self.totalUnreadCount = newTotalUnreadCount
                }
            }
    }

    private func getDirectChatRecipientName(for groupChat: GroupChat, currentUserID: String) -> String {
        if let recipientUsernames = groupChat.recipientUsernames,
           let recipientName = recipientUsernames.first(where: { $0 != currentUserID }) {
            return recipientName
        } else {
            return "Unknown"
        }
    }

    private func mergeGroupChats(existingChat: GroupChat, newChat: GroupChat, completion: @escaping (GroupChat) -> Void) {
        guard let existingChatId = existingChat.id, let newChatId = newChat.id else {
            completion(existingChat)
            return
        }

        let groupMessagesRef = db.collection("groups").document(existingChatId).collection("groupmessages")
        let newChatMessagesRef = db.collection("groups").document(newChatId).collection("groupmessages")

        newChatMessagesRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching messages for merging: \(error)")
                completion(existingChat)
                return
            }

            let batch = self.db.batch()

            // Move messages from the new chat to the existing chat
            snapshot?.documents.forEach { document in
                let newMessageRef = groupMessagesRef.document(document.documentID)
                batch.setData(document.data(), forDocument: newMessageRef)
            }

            // Commit the batch write
            batch.commit { error in
                if let error = error {
                    print("Error committing batch write for merging chats: \(error)")
                    completion(existingChat)
                } else {
                    // Delete the new chat document
                    self.db.collection("groups").document(newChatId).delete { error in
                        if let error = error {
                            print("Error deleting old chat after merge: \(error)")
                        }
                        completion(existingChat)
                    }
                }
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
