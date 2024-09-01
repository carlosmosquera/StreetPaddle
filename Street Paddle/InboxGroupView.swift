import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct InboxGroupView: View {
    @ObservedObject var chatManager = ChatManager()
    @State private var selectedGroupId: String? = nil
    @State private var searchText: String = ""

    init(selectedGroupId: String? = nil) {
        _selectedGroupId = State(initialValue: selectedGroupId)
    }

    var body: some View {
        NavigationStack {
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

                    // Search Bar
                    TextField("Search group chats...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .padding(.top, 8)

                    List {
                        ForEach(filteredGroupChats) { groupChat in
                            NavigationLink(
                                value: groupChat.id ?? ""
                            ) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(displayName(for: groupChat))
                                        .font(.headline)

                                    HStack {
                                        if let latestMessage = groupChat.latestMessage, !latestMessage.isEmpty {
                                            Text(latestMessage)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        } else {
                                            Text("No preview")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        if let timestamp = groupChat.latestMessageTimestamp {
                                            Text(timestamp.dateValue().formatted(date: .numeric, time: .shortened))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
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
                    .navigationDestination(for: String.self) { groupId in
                        GroupChatView(groupId: groupId)
                    }
                }
            }
        }
    }

    // Computed property to filter group chats based on the search text
    var filteredGroupChats: [GroupChat] {
        if searchText.isEmpty {
            return chatManager.groupChats
        } else {
            return chatManager.groupChats.filter { groupChat in
                displayName(for: groupChat).localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    func displayName(for groupChat: GroupChat) -> String {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return "Chat" }

        if let groupChatName = groupChat.groupChatName {
            // It's a group chat (3 or more users), return the group chat name
            return groupChatName
        } else if let creatorUserID = groupChat.creatorUserID, let creatorUsername = groupChat.creatorUsername {
            // It's a direct chat (2 users), determine the name based on the current user's role

            if creatorUserID == currentUserID {
                // Current user is the creator, so show the first recipient's username
                if let recipientUsernames = groupChat.recipientUsernames, !recipientUsernames.isEmpty {
                    return recipientUsernames.first ?? "Chat"
                } else {
                    return "Chat"
                }
            } else {
                // Current user is a recipient, so show the creator's username
                return creatorUsername
            }
        } else {
            // Fallback in case of missing data
            return "Chat"
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
