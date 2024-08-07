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
    var isRead: Bool = false
}

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var username: String
    var email: String
    var name: String // Add name field
}

struct InboxView: View {
    @State private var messages = [Message]()
    @State private var userNames = [String: String]()
    @State private var showingComposeMessage = false
    @State private var refreshMessages = false
    @State private var currentUsername = ""
    @State private var selectedSenderUsername: String?
    @State private var unreadMessageCount = 0

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(groupedMessages) { messageGroup in
                        NavigationLink(
                            destination: ChatView(senderUsername: messageGroup.senderUsername)
                                .onAppear {
                                    markMessagesAsRead(from: messageGroup.senderUsername)
                                },
                            tag: messageGroup.senderUsername,
                            selection: $selectedSenderUsername
                        ) {
                            VStack(alignment: .leading) {
                                Text(userNames[messageGroup.senderUsername] ?? messageGroup.senderUsername)
                                    .font(.headline)
                                Text(messageGroup.latestMessage.text)
                                    .lineLimit(1)
                                    .font(.subheadline)
                                Text(messageGroup.latestMessage.timestamp.dateValue(), style: .time)
                                    .font(.caption)
                                if messageGroup.latestMessage.isRead == false {
                                    Text("Unread")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
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
                .onAppear {
                    fetchCurrentUser()
                    fetchMessages()
                }
                .onChange(of: selectedSenderUsername) { _ in
                    fetchMessages()
                }
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
            .whereField("receiverId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }

                guard let documents = snapshot?.documents else { return }
                let fetchedMessages = documents.compactMap { doc in
                    try? doc.data(as: Message.self)
                }.sorted(by: { $0.timestamp.dateValue() > $1.timestamp.dateValue() })

                self.messages = fetchedMessages
                self.unreadMessageCount = fetchedMessages.filter { !$0.isRead }.count
                fetchSenderNames(for: fetchedMessages)
            }
    }

    func fetchSenderNames(for messages: [Message]) {
        let db = Firestore.firestore()
        let senderIds = Array(Set(messages.map { $0.senderId }))

        senderIds.forEach { senderId in
            db.collection("users").document(senderId).getDocument { document, error in
                if let document = document, document.exists, let data = document.data(), let name = data["name"] as? String {
                    DispatchQueue.main.async {
                        self.userNames[senderId] = name
                    }
                }
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
            if message.receiverId == userId {
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

    func markMessagesAsRead(from senderUsername: String) {
        let db = Firestore.firestore()
        guard let userId = Auth.auth().currentUser?.uid else { return }

        db.collection("messages")
            .whereField("receiverId", isEqualTo: userId)
            .whereField("senderUsername", isEqualTo: senderUsername)
            .whereField("isRead", isEqualTo: false) // Only update unread messages
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error marking messages as read: \(error.localizedDescription)")
                    return
                }

                snapshot?.documents.forEach { document in
                    document.reference.updateData(["isRead": true]) { error in
                        if let error = error {
                            print("Error updating message status: \(error.localizedDescription)")
                        }
                    }
                }

                // Update local unread message count
                self.unreadMessageCount -= snapshot?.documents.count ?? 0
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
