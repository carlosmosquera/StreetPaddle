import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct Message: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var senderId: String
    var senderUsername: String
    var receiverId: String
    var receiverUsername: String
    var text: String
    var timestamp: Timestamp
}


struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var username: String
    var email: String
}


struct InboxView: View {
    @State private var messages = [Message]()
    @State private var showingComposeMessage = false
    @State private var refreshMessages = false
    @State private var currentUsername = ""
    @State private var selectedSenderUsername: String?

    var body: some View {
        NavigationView {
            VStack {
                Text("Welcome, \(currentUsername)")
                    .font(.headline)
                    .padding()
                
                List {
                    ForEach(groupedMessages) { messageGroup in
                        NavigationLink(
                            destination: ChatView(senderUsername: messageGroup.senderUsername),
                            tag: messageGroup.senderUsername,
                            selection: $selectedSenderUsername
                        ) {
                            VStack(alignment: .leading) {
                                Text(messageGroup.senderUsername)
                                    .font(.headline)
                                Text(messageGroup.latestMessage.text)
                                    .lineLimit(1)
                                    .font(.subheadline)
                                Text(messageGroup.latestMessage.timestamp.dateValue(), style: .time)
                                    .font(.caption)
                            }
                            .padding()
                        }
                        .onTapGesture {
                            self.selectedSenderUsername = messageGroup.senderUsername
                        }
                    }
                    .onDelete(perform: deleteMessage)
                }
                .navigationBarTitle("Inbox")
                .navigationBarItems(trailing: Button(action: {
                    showingComposeMessage.toggle()
                }) {
                    Image(systemName: "square.and.pencil")
                })
                .sheet(isPresented: $showingComposeMessage) {
                    ComposeMessageView(refreshMessages: $refreshMessages)
                }
                .onChange(of: refreshMessages) { _ in
                    fetchMessages()
                    refreshMessages = false
                }
            }
            .onAppear {
                fetchCurrentUser()
                fetchMessages()
            }
        }
    }

    func fetchCurrentUser() {
        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? ""

        db.collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists, let data = document.data(), let username = data["username"] as? String {
                self.currentUsername = username
            } else {
                print("Failed to fetch current user's username.")
            }
        }
    }

    func fetchMessages() {
        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? ""

        db.collection("messages")
            .whereField("receiverId", isEqualTo: userId) // Fetch only messages where the current user is the receiver
            .getDocuments { sentSnapshot, sentError in
                if let sentError = sentError {
                    print(sentError.localizedDescription)
                    return
                }

                db.collection("messages")
                    .whereField("senderId", isEqualTo: userId) // Fetch only messages where the current user is the sender
                    .getDocuments { receivedSnapshot, receivedError in
                        if let receivedError = receivedError {
                            print(receivedError.localizedDescription)
                            return
                        }

                        var combinedMessages = [Message]()

                        if let sentSnapshot = sentSnapshot {
                            let sentMessages = sentSnapshot.documents.compactMap { doc in
                                try? doc.data(as: Message.self)
                            }
                            combinedMessages.append(contentsOf: sentMessages)
                        }

                        if let receivedSnapshot = receivedSnapshot {
                            let receivedMessages = receivedSnapshot.documents.compactMap { doc in
                                try? doc.data(as: Message.self)
                            }
                            combinedMessages.append(contentsOf: receivedMessages)
                        }

                        self.messages = combinedMessages.sorted(by: { $0.timestamp.dateValue() > $1.timestamp.dateValue() })
                    }
            }
    }

    var groupedMessages: [MessageGroup] {
        let grouped = Dictionary(grouping: messages, by: { $0.senderUsername })
        return grouped.map { (key, value) in
            let latestMessage = value.max(by: { $0.timestamp.dateValue() < $1.timestamp.dateValue() })!
            return MessageGroup(senderUsername: key, latestMessage: latestMessage)
        }
    }

    func deleteMessage(at offsets: IndexSet) {
        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? ""

        offsets.forEach { index in
            let message = messages[index]
            if message.senderId == userId || message.receiverId == userId {
                if let messageId = message.id {
                    db.collection("messages").document(messageId).delete { error in
                        if let error = error {
                            print("Error deleting message: \(error.localizedDescription)")
                        } else {
                            messages.remove(at: index)
                        }
                    }
                }
            }
        }
    }
}

struct MessageGroup: Identifiable {
    var id: String { senderUsername }
    var senderUsername: String
    var latestMessage: Message
}


#Preview {
    InboxView()
}
