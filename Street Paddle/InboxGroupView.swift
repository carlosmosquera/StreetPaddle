import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct InboxGroupView: View {
    @State private var groupChats = [GroupChat]()
    @State private var selectedGroupId: String?
    @State private var userName: String = "" // New state property for user's name

    var body: some View {
        
        ZStack {
            
            Image(.court)
                .resizable()
                .opacity(0.3)
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            VStack {
                        // Display the user's name at the top center
                        Text(userName)
                            .font(.title)
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        List {
                            ForEach(groupChats) { groupChat in
                                NavigationLink(
                                    destination: GroupChatView(groupId: groupChat.id ?? ""),
                                    tag: groupChat.id ?? "",
                                    selection: $selectedGroupId
                                ) {
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text(groupChat.name)
                                                .font(.headline)
                                            Spacer()
                                            if let timestamp = groupChat.latestMessageTimestamp {
                                                Text(timestamp.dateValue().formatted(date: .numeric, time: .shortened))
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        if let latestMessage = groupChat.latestMessage {
                                            Text(latestMessage)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .contextMenu {
                                    Button(action: {
                                        // Add any additional actions here (e.g., leave group)
                                    }) {
                                        Text("Leave Group")
                                        Image(systemName: "arrow.right.circle")
                                    }
                                }
                            }
                            .onDelete(perform: deleteGroupChat) // Add delete functionality
                        }
                        .navigationTitle("Inbox")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                NavigationLink(destination: CreateGroupChatView()) {
                                    Image(systemName: "square.and.pencil")
                                }
                            }
                        }
                        .onAppear(perform: fetchGroupChats)
            }
        }
            
        
    }

    func fetchGroupChats() {
        let db = Firestore.firestore()
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

            self.userName = name
        }

        db.collection("groups")
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
                        db.collection("groups")
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

    func deleteGroupChat(at offsets: IndexSet) {
        let db = Firestore.firestore()
        guard let userId = Auth.auth().currentUser?.uid else { return }

        offsets.forEach { index in
            let groupChat = groupChats[index]

            // Delete the group chat document from Firestore
            if let groupId = groupChat.id {
                db.collection("groups").document(groupId).delete { error in
                    if let error = error {
                        print("Error deleting group chat: \(error)")
                    } else {
                        print("Group chat successfully deleted!")
                    }
                }
            }

            // Remove the group chat from the local array
            groupChats.remove(at: index)
        }
    }
}

struct GroupChat: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var latestMessage: String?
    var latestMessageTimestamp: Timestamp?
}

#Preview {
    InboxGroupView()
}
