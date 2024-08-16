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

            self.db.collection("groups")
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
                        updatedGroupChats.append(groupChat ?? GroupChat(id: nil, name: "", latestMessage: nil, latestMessageTimestamp: nil))
                    }

                    dispatchGroup.notify(queue: .main) {
                        self.updateGroupChatsWithNames(from: updatedGroupChats)
                    }
                }
        }
    }

    private func updateGroupChatsWithNames(from groupChats: [GroupChat]) {
        let dispatchGroup = DispatchGroup()
        
        var updatedGroupChats = groupChats
        
        for index in groupChats.indices {
            let groupChat = groupChats[index]
            if !groupChat.name.isEmpty {
                dispatchGroup.enter()
                self.db.collection("users")
                    .whereField("username", isEqualTo: groupChat.name)
                    .getDocuments { snapshot, error in
                        if let error = error {
                            print("Error fetching user: \(error.localizedDescription)")
                            dispatchGroup.leave()
                            return
                        }
                        
                        if let document = snapshot?.documents.first {
                            let userName = document.get("name") as? String ?? ""
                            updatedGroupChats[index].name = "\(userName) (\(groupChat.name))"
                        }
                        
                        dispatchGroup.leave()
                    }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.groupChats = updatedGroupChats
        }
    }
}
