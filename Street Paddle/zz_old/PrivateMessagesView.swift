//import SwiftUI
//import FirebaseFirestore
//import FirebaseAuth
//
//struct PrivateMessagesView: View {
//    @State private var conversations = [Conversation]()
//    @State private var showingNewMessageView = false
//
//    var body: some View {
//        NavigationView {
//            VStack {
//                List(conversations) { conversation in
//                    NavigationLink(destination: ChatView(recipientUsername: conversation.otherUsername)) {
//                        Text(conversation.otherUsername)
//                    }
//                }
//                .listStyle(PlainListStyle())
//            }
//            .navigationTitle("Inbox")
//            .navigationBarItems(trailing: Button(action: {
//                showingNewMessageView = true
//            }) {
//                Image(systemName: "square.and.pencil")
//            })
//            .sheet(isPresented: $showingNewMessageView) {
//                NewMessageView()
//            }
//            .onAppear {
//                fetchConversations()
//            }
//        }
//    }
//
//    func fetchConversations() {
//        guard let user = Auth.auth().currentUser else { return }
//
//        let db = Firestore.firestore()
//        db.collection("privateMessages")
//            .whereField("participants", arrayContains: user.uid)
//            .getDocuments { snapshot, error in
//                if let error = error {
//                    print("Error fetching conversations: \(error.localizedDescription)")
//                } else {
//                    let messages = snapshot?.documents.compactMap { document in
//                        try? document.data(as: PrivateMessage.self)
//                    } ?? []
//
//                    let groupedMessages = Dictionary(grouping: messages) { message -> String in
//                        message.participants.first { $0 != user.uid } ?? ""
//                    }
//
//                    conversations = groupedMessages.map { (key, value) in
//                        Conversation(otherUsername: key, lastMessage: value.last?.content ?? "")
//                    }
//                }
//            }
//    }
//}
//
//struct Conversation: Identifiable {
//    var id: String { otherUsername }
//    var otherUsername: String
//    var lastMessage: String
//}
//
//struct NewMessageView: View {
//    @Environment(\.presentationMode) var presentationMode
//    @State private var recipientUsername = ""
//    @State private var errorMessage = ""
//    @State private var chatRecipient: String? = nil
//
//    var body: some View {
//        VStack {
//            TextField("Recipient Username", text: $recipientUsername)
//                .padding()
//                .background(Color.gray.opacity(0.2))
//                .cornerRadius(5.0)
//                .padding(.bottom, 20)
//
//            Button(action: checkRecipient) {
//                Text("Start Chat")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .padding()
//                    .frame(width: 220, height: 60)
//                    .background(Color.blue)
//                    .cornerRadius(15.0)
//            }
//
//            if !errorMessage.isEmpty {
//                Text(errorMessage)
//                    .foregroundColor(.red)
//                    .padding()
//            }
//
//            NavigationLink(destination: ChatView(recipientUsername: chatRecipient ?? ""), isActive: Binding<Bool>(
//                get: { chatRecipient != nil },
//                set: { if !$0 { chatRecipient = nil } }
//            )) {
//                EmptyView()
//            }
//        }
//        .padding()
//    }
//
//    func checkRecipient() {
//        let db = Firestore.firestore()
//        db.collection("users")
//            .whereField("username", isEqualTo: recipientUsername)
//            .getDocuments { snapshot, error in
//                if let error = error {
//                    errorMessage = "Error finding recipient: \(error.localizedDescription)"
//                } else if snapshot?.isEmpty == true {
//                    errorMessage = "Recipient not found"
//                } else {
//                    chatRecipient = recipientUsername
//                    errorMessage = ""
//                    presentationMode.wrappedValue.dismiss()
//                }
//            }
//    }
//}
//
//struct ChatView: View {
//    let recipientUsername: String
//    @State private var newMessage = ""
//    @State private var messages = [PrivateMessage]()
//    @State private var senderUsername = ""
//    @State private var recipientID = ""
//
//    var body: some View {
//        VStack {
//            List(messages) { message in
//                HStack {
//                    if message.senderUsername == senderUsername {
//                        Spacer()
//                        Text(message.content)
//                            .padding(10)
//                            .background(Color.blue.opacity(0.2))
//                            .cornerRadius(10)
//                            .frame(maxWidth: .infinity, alignment: .trailing)
//                    } else {
//                        Text(message.content)
//                            .padding(10)
//                            .background(Color.blue.opacity(0.2))
//                            .cornerRadius(10)
//                            .frame(maxWidth: .infinity, alignment: .leading)
//                        Spacer()
//                    }
//                }
//                .padding(.horizontal)
//            }
//            .listStyle(PlainListStyle())
//
//            HStack {
//                TextField("Enter your message", text: $newMessage)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .frame(minHeight: 30)
//                
//                Button(action: sendMessage) {
//                    Text("Send")
//                        .foregroundColor(.white)
//                        .padding()
//                        .background(Color.blue)
//                        .cornerRadius(15)
//                }
//            }
//            .padding()
//        }
//        .navigationTitle(recipientUsername)
//        .onAppear {
//            fetchSenderUsername {
//                fetchRecipientID {
//                    fetchMessages()
//                }
//            }
//        }
//    }
//
//    func fetchSenderUsername(completion: @escaping () -> Void) {
//        guard let user = Auth.auth().currentUser else { return }
//
//        let db = Firestore.firestore()
//        db.collection("users").document(user.uid).getDocument { document, error in
//            if let error = error {
//                print("Error fetching sender: \(error.localizedDescription)")
//                return
//            }
//            guard let document = document, document.exists, let data = document.data(), let username = data["username"] as? String else {
//                print("Sender does not have a username")
//                return
//            }
//            senderUsername = username
//            completion()
//        }
//    }
//
//    func fetchRecipientID(completion: @escaping () -> Void) {
//        let db = Firestore.firestore()
//        db.collection("users")
//            .whereField("username", isEqualTo: recipientUsername)
//            .getDocuments { snapshot, error in
//                if let error = error {
//                    print("Error finding recipient: \(error.localizedDescription)")
//                    return
//                } else if snapshot?.isEmpty == true {
//                    print("Recipient not found")
//                    return
//                } else {
//                    guard let document = snapshot?.documents.first else {
//                        print("Recipient not found")
//                        return
//                    }
//                    recipientID = document.documentID
//                    completion()
//                }
//            }
//    }
//
//    func fetchMessages() {
//        guard let user = Auth.auth().currentUser else { return }
//
//        let db = Firestore.firestore()
//        db.collection("privateMessages")
//            .whereField("participants", arrayContainsAny: [user.uid, recipientID])
//            .order(by: "timestamp", descending: false)
//            .addSnapshotListener { snapshot, error in
//                if let error = error {
//                    print("Error fetching messages: \(error.localizedDescription)")
//                } else {
//                    messages = snapshot?.documents.compactMap { document in
//                        try? document.data(as: PrivateMessage.self)
//                    } ?? []
//                }
//            }
//    }
//
//    func sendMessage() {
//        guard let user = Auth.auth().currentUser else { return }
//
//        let db = Firestore.firestore()
//        let messageData: [String: Any] = [
//            "content": newMessage,
//            "timestamp": Timestamp(date: Date()),
//            "senderUsername": senderUsername,
//            "participants": [user.uid, recipientID]
//        ]
//
//        db.collection("privateMessages").addDocument(data: messageData) { error in
//            if let error = error {
//                print("Error sending message: \(error.localizedDescription)")
//            } else {
//                // Add the new message to the local array to display it immediately
//                messages.append(PrivateMessage(
//                    id: nil,
//                    content: newMessage,
//                    timestamp: Timestamp(date: Date()),
//                    senderUsername: senderUsername,
//                    participants: [user.uid, recipientID]
//                ))
//                newMessage = ""
//            }
//        }
//    }
//}
//
//struct PrivateMessage: Identifiable, Codable {
//    @DocumentID var id: String?
//    var content: String
//    var timestamp: Timestamp
//    var senderUsername: String
//    var participants: [String]
//}
//
//#Preview {
//    PrivateMessagesView()
//}
