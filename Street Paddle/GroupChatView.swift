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
        ZStack {
            Image(.court)
                .resizable()
                .opacity(0.3)
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
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
                                    VStack(alignment: .leading) {
                                        HStack {
                                            if message.senderId == Auth.auth().currentUser?.uid {
                                                Spacer()
                                                VStack(alignment: .trailing) {
                                                    Text(message.text)
                                                        .padding()
                                                        .background(Color.blue)
                                                        .cornerRadius(8)
                                                        .foregroundColor(.white)
                                                        .id(message.id) // Assign unique ID to each message
                                                    
                                                    Text(message.timestamp.dateValue(), formatter: messageTimeFormatter)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .padding(.top, 2)
                                                    
                                                    Text(message.senderName ?? "Unknown")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }
                                            } else {
                                                VStack(alignment: .leading) {
                                                    Text(message.text)
                                                        .padding()
                                                        .background(Color.gray.opacity(0.2))
                                                        .cornerRadius(8)
                                                        .id(message.id) // Assign unique ID to each message
                                                    
                                                    Text(message.timestamp.dateValue(), formatter: messageTimeFormatter)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .padding(.top, 2)
                                                    
                                                    Text(message.senderName ?? "Unknown")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
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
                
                let userNameDict = snapshot?.documents.reduce(into: [String: String]()) { dict, document in
                    if let name = document.data()["name"] as? String {
                        dict[document.documentID] = name
                    }
                }
                
                // Update user names for the header
                self.userNames = memberIds.compactMap { userNameDict?[$0] }
                
                // Fetch group messages
                db.collection("groups").document(groupId).collection("groupmessages")
                    .order(by: "timestamp")
                    .addSnapshotListener { snapshot, error in
                        if let error = error {
                            print("Error fetching messages: \(error)")
                            return
                        }
                        
                        guard let documents = snapshot?.documents else { return }
                        
                        self.groupMessages = documents.compactMap { document -> GroupMessage? in
                            var message = try? document.data(as: GroupMessage.self)
                            // Set the sender's name
                            if let senderId = message?.senderId {
                                message?.senderName = userNameDict?[senderId]
                            }
                            return message
                        }
                    }
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
    var senderName: String? // Add this line

    static func == (lhs: GroupMessage, rhs: GroupMessage) -> Bool {
        return lhs.id == rhs.id
    }
}

// Date formatter for message timestamps
private let messageTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    GroupChatView(groupId: "exampleGroupId")
}
