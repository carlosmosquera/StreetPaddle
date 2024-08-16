import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct InboxGroupView: View {
    @ObservedObject var chatManager = ChatManager()
    @State private var selectedGroupId: String? = nil

    init(selectedGroupId: String? = nil) {
        _selectedGroupId = State(initialValue: selectedGroupId)
    }

    var body: some View {
        ZStack {
            Image(.court)
                .resizable()
                .opacity(0.3)
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            VStack {
                Text(chatManager.groupChats.isEmpty ? "No Chats" : "Chats")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)

                List {
                    ForEach(chatManager.groupChats) { groupChat in
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
                    .onDelete(perform: deleteGroupChat)
                }
                .navigationTitle("Inbox")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: CreateGroupChatView(chatManager: chatManager)) {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
                .onAppear {
                    chatManager.fetchGroupChats()
                    
                    // Automatically navigate to the selected chat if needed
                    if let selectedGroupId = selectedGroupId {
                        DispatchQueue.main.async {
                            self.selectedGroupId = selectedGroupId
                        }
                    }
                }
            }
        }
    }

    func deleteGroupChat(at offsets: IndexSet) {
        let db = Firestore.firestore()
        guard let userId = Auth.auth().currentUser?.uid else { return }

        offsets.forEach { index in
            if index < chatManager.groupChats.count {
                let groupChat = chatManager.groupChats[index]

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
                chatManager.groupChats.remove(at: index)
            }
        }
    }
}

#Preview {
    InboxGroupView()
}

struct GroupChat: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var latestMessage: String?
    var latestMessageTimestamp: Timestamp?
}
