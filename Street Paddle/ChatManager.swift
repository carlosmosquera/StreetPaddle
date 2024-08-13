import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class ChatManager: ObservableObject {
    @Published var groupChats: [GroupChat] = []

    private var db = Firestore.firestore()

    func fetchGroupChats() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Fetch the current user's name
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error)")
                return
            }

            guard let data = document?.data(), let name = data["name"] as? String else {
                print("User data is missing or malformed.")
                return
            }

            self.groupChats = []
            self.db.collection("groups")
                .whereField("members", arrayContains: userId)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error fetching groups: \(error)")
                        return
                    }

                    guard let documents = snapshot?.documents else { return }

                    self.groupChats = documents.compactMap { document -> GroupChat? in
                        var groupChat = try? document.data(as: GroupChat.self)
                        
                        // Fetch the latest message for each group
                        if let groupId = groupChat?.id {
                            self.db.collection("groups")
                                .document(groupId)
                                .collection("groupmessages")
                                .order(by: "timestamp", descending: true)
                                .limit(to: 1)
                                .getDocuments { messageSnapshot, error in
                                    if let error = error {
                                        print("Error fetching latest message: \(error)")
                                        return
                                    }
                                    
                                    if let messageDoc = messageSnapshot?.documents.first {
                                        groupChat?.latestMessage = messageDoc.data()["text"] as? String
                                        groupChat?.latestMessageTimestamp = messageDoc.data()["timestamp"] as? Timestamp
                                        
                                        // Update the group chat in the list
                                        if let updatedGroupChat = groupChat,
                                           let index = self.groupChats.firstIndex(where: { $0.id == updatedGroupChat.id }) {
                                            self.groupChats[index] = updatedGroupChat
                                        }
                                    }
                                }
                        }
                        
                        return groupChat
                    }
                }
        }
    }
}
