import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class ChatManager: ObservableObject {
    @Published var groupChats: [GroupChat] = []
    private var db = Firestore.firestore()

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
                        self.db.collection("groups")
                            .document(groupChatId)
                            .collection("groupmessages")
                            .order(by: "timestamp", descending: true)
                            .limit(to: 1)
                            .getDocuments { messageSnapshot, error in
                                if let error = error {
                                    print("Error fetching latest message: \(error)")
                                    dispatchGroup.leave()
                                    return
                                }
                                
                                if let messageDoc = messageSnapshot?.documents.first {
                                    groupChat?.latestMessage = messageDoc.data()["text"] as? String
                                    groupChat?.latestMessageTimestamp = messageDoc.data()["timestamp"] as? Timestamp
                                }
                                
                                dispatchGroup.leave()
                            }
                    }
                    if let chat = groupChat {
                        updatedGroupChats.append(chat)
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    self.groupChats = updatedGroupChats
                }
            }
    }
}
