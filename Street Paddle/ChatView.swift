import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ChatView: View {
    var senderUsername: String
    @State private var chatMessages = [Message]()
    @State private var newMessageText = ""
    @State private var senderId: String?
    @State private var recipientUsername: String?
    @Namespace private var scrollNamespace

    var body: some View {
        VStack {
            // Recipient username at the top center
            if let recipientUsername = recipientUsername {
                Text(recipientUsername)
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.top)
            }
            
            ScrollViewReader { scrollView in
                ScrollView {
                    VStack {
                        ForEach(chatMessages) { chatMessage in
                            HStack {
                                if chatMessage.senderId == Auth.auth().currentUser?.uid {
                                    Spacer()
                                    Text(chatMessage.text)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                        .foregroundColor(.white)
                                } else {
                                    Text(chatMessage.text)
                                        .padding()
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                    Spacer()
                                }
                            }
                            .padding()
                            .id(chatMessage.id) // Assign unique ID to each message
                        }
                    }
                }
                .onChange(of: chatMessages) { _ in
                    if let lastMessageId = chatMessages.last?.id {
                        withAnimation {
                            scrollView.scrollTo(lastMessageId, anchor: .bottom)
                        }
                    }
                }
            }
            HStack {
                TextField("Message", text: $newMessageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: sendMessage) {
                    Text("Send")
                }
                .padding(.horizontal)
                .disabled(newMessageText.isEmpty) // Disable button if message is empty
            }
            .padding()
        }
        .onAppear {
            fetchSenderIdAndMessages()
        }
    }

    func fetchSenderIdAndMessages() {
        let db = Firestore.firestore()

        // Fetch senderId based on senderUsername
        db.collection("users")
            .whereField("username", isEqualTo: senderUsername)
            .getDocuments { snapshot, error in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    print("Sender not found")
                    return
                }
                
                self.senderId = document.documentID
                self.recipientUsername = senderUsername // Set recipientUsername

                // Fetch chat messages between current user and the sender
                fetchChatMessages()
            }
    }

    func fetchChatMessages() {
        guard let senderId = senderId else { return }
        let userId = Auth.auth().currentUser?.uid ?? ""
        let db = Firestore.firestore()

        db.collection("messages")
            .whereField("senderId", in: [userId, senderId])
            .whereField("receiverId", in: [userId, senderId])
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                
                self.chatMessages = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Message.self)
                } ?? []
            }
    }

    func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespaces).isEmpty else { return } // Check for empty messages
        guard let senderId = senderId else { return }
        let userId = Auth.auth().currentUser?.uid ?? ""
        let db = Firestore.firestore()

        // Fetch the current user's username from Firestore
        db.collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists, let data = document.data(), let username = data["username"] as? String {
                let newMessage = Message(senderId: userId, senderUsername: username, receiverId: senderId, receiverUsername: senderUsername, text: newMessageText, timestamp: Timestamp(date: Date()))

                do {
                    _ = try db.collection("messages").addDocument(from: newMessage)
                    newMessageText = ""
                } catch {
                    print(error.localizedDescription)
                }
            } else {
                print("User document does not exist or failed to fetch username.")
            }
        }
    }
}
#Preview {
    ChatView(senderUsername: "Papito")
}
