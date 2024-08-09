import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct GroupChatView: View {
    var groupId: String
    @State private var messageText = ""
    @State private var groupMessages = [GroupMessage]()
    @State private var userNames = [String]()
    @Namespace private var scrollNamespace

    var body: some View {
        VStack {
            // Compact header with user names
            VStack {
                HStack {
                    Text(userNames.joined(separator: ", "))
                        .font(.headline)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(10)
                .padding(.top, 10) // Adjust top padding to reduce space

                // Chat messages view
                ScrollViewReader { scrollView in
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(groupMessages) { message in
                                HStack {
                                    if message.senderId == Auth.auth().currentUser?.uid {
                                        Spacer()
                                        Text(message.text)
                                            .padding()
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                            .foregroundColor(.white)
                                            .id(message.id) // Assign unique ID to each message
                                    } else {
                                        Text(message.text)
                                            .padding()
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(8)
                                            .id(message.id) // Assign unique ID to each message
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .onChange(of: groupMessages) { _ in
                        if let lastMessageId = groupMessages.last?.id {
                            withAnimation {
                                scrollView.scrollTo(lastMessageId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Message input area
                HStack {
                    TextField("Enter message", text: $messageText)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(5.0)
                    
                    Button(action: sendMessage) {
                        Text("Send")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(5.0)
                    }
                    .disabled(messageText.isEmpty) // Disable if message is empty
                }
                .padding()
            }
        }
        .onAppear(perform: fetchGroupData)
    }
    
    func fetchGroupData() {
        let db = Firestore.firestore()
        
        // Fetch group details to get member IDs
        db.collection("groups").document(groupId).getDocument { document, error in
            if let error = error {
                print("Error fetching group details: \(error)")
                return
            }
            
            guard let data = document?.data(), let memberIds = data["members"] as? [String] else {
                print("Group data is missing or malformed.")
                return
            }
            
            // Fetch names for all members
            db.collection("users").whereField(FieldPath.documentID(), in: memberIds).getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching user names: \(error)")
                    return
                }
                
                self.userNames = snapshot?.documents.compactMap { document in
                    return document.data()["name"] as? String
                } ?? []
            }
        }
        
        // Fetch group messages
        db.collection("groups").document(groupId).collection("groupmessages") // Ensure collection name is correct
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching messages: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.groupMessages = documents.compactMap { document -> GroupMessage? in
                    return try? document.data(as: GroupMessage.self)
                }
            }
    }
    
    func sendMessage() {
        let db = Firestore.firestore()
        guard !messageText.isEmpty else { return }
        
        db.collection("groups").document(groupId).collection("groupmessages").addDocument(data: [
            "senderId": Auth.auth().currentUser?.uid ?? "",
            "text": messageText,
            "timestamp": Timestamp()
        ]) { error in
            if let error = error {
                print("Error sending message: \(error)")
            }
        }
        
        messageText = ""
    }
}

// Define the GroupMessage struct with Equatable conformance
struct GroupMessage: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    var timestamp: Timestamp
    
    static func == (lhs: GroupMessage, rhs: GroupMessage) -> Bool {
        return lhs.id == rhs.id
    }
}

#Preview {
    GroupChatView(groupId: "exampleGroupId")
}
