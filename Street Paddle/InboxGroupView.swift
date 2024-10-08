import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct InboxGroupView: View {
    @ObservedObject var chatManager: ChatManager
    @State private var selectedGroupId: String? = nil
    @State private var searchText: String = ""
    @State private var userNameCache: [String: String] = [:] // Cache for user names
    private var db = Firestore.firestore() // Firestore reference

    init(chatManager: ChatManager, selectedGroupId: String? = nil) {
        _chatManager = ObservedObject(wrappedValue: chatManager)
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
                                HStack {
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

                                    Spacer()

                                    // Conditionally display the badge for unread messages
                                    if let unreadCount = groupChat.unreadCount, unreadCount > 0 {
                                        Text("\(unreadCount)")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Color.red)
                                            .clipShape(Circle())
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
            return groupChatName
        } else if let creatorUserID = groupChat.creatorUserID, let creatorUsername = groupChat.creatorUsername {
            if creatorUserID == currentUserID {
                if let recipientUsername = groupChat.recipientUsernames?.first {
                    fetchUserNameByUsername(recipientUsername) { name in
                        if let name = name {
                            self.userNameCache[recipientUsername] = name
                        }
                    }
                    return "\(recipientUsername)" + (userNameCache[recipientUsername] != nil ? " (\(userNameCache[recipientUsername]!))" : "")
                } else {
                    return "Chat"
                }
            } else {
                fetchUserNameByUsername(creatorUsername) { name in
                    if let name = name {
                        self.userNameCache[creatorUsername] = name
                    }
                }
                return "\(creatorUsername)" + (userNameCache[creatorUsername] != nil ? " (\(userNameCache[creatorUsername]!))" : "")
            }
        } else {
            return "Chat"
        }
    }

    func fetchUserNameByUsername(_ username: String, completion: @escaping (String?) -> Void) {
        db.collection("users").whereField("username", isEqualTo: username).getDocuments { querySnapshot, error in
            if let error = error {
                print("Error fetching user name by username: \(error)")
                completion(nil)
            } else if let document = querySnapshot?.documents.first, let name = document.data()["name"] as? String {
                completion(name)
            } else {
                completion(nil)
            }
        }
    }

    func deleteGroupChat(at offsets: IndexSet) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        offsets.forEach { index in
            if index < chatManager.groupChats.count {
                let groupChat = chatManager.groupChats[index]

                if let groupId = groupChat.id {
                    db.collection("groups").document(groupId).delete { error in
                        if let error = error {
                            print("Error deleting group chat: \(error)")
                        } else {
                            print("Group chat successfully deleted!")
                        }
                    }
                }

                chatManager.groupChats.remove(at: index)
            }
        }
    }
}
