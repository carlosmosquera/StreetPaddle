import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct InboxGroupView: View {
    @ObservedObject var chatManager: ChatManager
    @State private var searchText: String = ""
    @State private var hiddenGroupChats: Set<String> = [] // Track hidden group chats
    @State private var userNameCache: [String: String] = [:] // Cache for user names
    @State private var messagesListener: ListenerRegistration? // Listener for real-time message updates
    private var db = Firestore.firestore() // Firestore reference
    private let hiddenChatsKey = "hiddenGroupChats" // Key for UserDefaults

    init(chatManager: ChatManager) {
        _chatManager = ObservedObject(wrappedValue: chatManager)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(.court)
                    .resizable()
                    .opacity(0.3)
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                VStack {
                    HeaderView(chatManager: chatManager)

                    SearchBar(searchText: $searchText)

                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(filteredGroupChats) { groupChat in
                                GroupChatRow(
                                    groupChat: groupChat,
                                    isHidden: hiddenGroupChats.contains(groupChat.id ?? ""),
                                    hideAction: { hideGroupChat(groupChat: groupChat) },
                                    unhideAction: { unhideGroupChat(groupChat: groupChat) },
                                    displayName: displayName(for: groupChat)
                                )
                            }
                        }
                        .padding(.horizontal)
                        .frame(width: geometry.size.width)
                    }
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .navigationTitle("Inbox")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: CreateGroupChatView(chatManager: chatManager)) {
                                Image(systemName: "square.and.pencil")
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadHiddenGroupChats()  // Load hidden group chats from UserDefaults
            listenForGroupChats()   // Real-time listener for group chats
            listenForUnreadMessages() // Real-time listener for unread messages
        }
        .onDisappear {
            stopListening()  // Stop all listeners when the view disappears
        }
    }

    // Extracted Functionality for Hiding/Unhiding Group Chats
    func unhideGroupChat(groupChat: GroupChat) {
        if let groupId = groupChat.id {
            hiddenGroupChats.remove(groupId)
            saveHiddenGroupChats() // Save to UserDefaults
        }
    }

    func hideGroupChat(groupChat: GroupChat) {
        if let groupId = groupChat.id {
            hiddenGroupChats.insert(groupId)
            saveHiddenGroupChats() // Save to UserDefaults
        }
    }

    // Load and Save Hidden Chats
    func loadHiddenGroupChats() {
        if let savedChats = UserDefaults.standard.array(forKey: hiddenChatsKey) as? [String] {
            DispatchQueue.main.async {
                hiddenGroupChats = Set(savedChats)
            }
        }
    }

    func saveHiddenGroupChats() {
        UserDefaults.standard.set(Array(hiddenGroupChats), forKey: hiddenChatsKey)
    }

    // Real-time listener for group chats
    func listenForGroupChats() {
        guard let user = Auth.auth().currentUser else { return }
        messagesListener = db.collection("groups")
            .whereField("members", arrayContains: user.uid)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching group chats: \(error.localizedDescription)")
                    return
                }
                
                let groupChats = snapshot?.documents.compactMap { document -> GroupChat? in
                    try? document.data(as: GroupChat.self)
                } ?? []
                
                DispatchQueue.main.async {
                    chatManager.groupChats = groupChats
                }
            }
    }

    // Real-time listener for unread messages
    func listenForUnreadMessages() {
        guard let user = Auth.auth().currentUser else { return }
        db.collection("groups")
            .whereField("members", arrayContains: user.uid)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching group messages: \(error.localizedDescription)")
                    return
                }

                snapshot?.documents.forEach { document in
                    let groupId = document.documentID
                    
                    self.fetchUnreadCount(for: groupId) { unreadCount in
                        self.updateGroupUnreadCount(groupId: groupId, unreadCount: unreadCount)
                        
                        // Only unhide the group chat if a new message is received
                        if unreadCount > 0 && self.hiddenGroupChats.contains(groupId) {
                            self.hiddenGroupChats.remove(groupId)
                            self.saveHiddenGroupChats()
                        }
                    }
                }
            }
    }

    // Stop all listeners when the view disappears
    func stopListening() {
        messagesListener?.remove()
    }

    // Fetch unread count for each group chat
    func fetchUnreadCount(for groupChatId: String, completion: @escaping (Int) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userLastReadDocRef = db.collection("groups").document(groupChatId).collection("members").document(userId)
        
        userLastReadDocRef.getDocument { document, error in
            if let error = error {
                print("Error fetching last read timestamp: \(error)")
                completion(0)
                return
            }
            
            guard let document = document, let lastReadTimestamp = document.data()?["lastReadTimestamp"] as? Timestamp else {
                completion(0)
                return
            }
            
            db.collection("groups").document(groupChatId).collection("groupmessages")
                .whereField("timestamp", isGreaterThan: lastReadTimestamp)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching unread messages: \(error)")
                        completion(0)
                        return
                    }
                    
                    let unreadCount = snapshot?.documents.count ?? 0
                    completion(unreadCount)
                }
        }
    }

    // Update unread message count in the UI
    func updateGroupUnreadCount(groupId: String, unreadCount: Int) {
        if let index = chatManager.groupChats.firstIndex(where: { $0.id == groupId }) {
            chatManager.groupChats[index].unreadCount = unreadCount
        }
    }

    // Function to display group chat names
    func displayName(for groupChat: GroupChat) -> String {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return "Chat" }
        
        if let groupChatName = groupChat.groupChatName {
            return groupChatName
        } else if let creatorUserID = groupChat.creatorUserID, let creatorUsername = groupChat.creatorUsername {
            if creatorUserID == currentUserID {
                if let recipientUsername = groupChat.recipientUsernames?.first {
                    return recipientUsername
                } else {
                    return "Chat"
                }
            } else {
                return creatorUsername
            }
        } else {
            return "Chat"
        }
    }

    // Computed property for filtered group chats
    var filteredGroupChats: [GroupChat] {
        let visibleChats = chatManager.groupChats.filter { !hiddenGroupChats.contains($0.id ?? "") }
        let hiddenChats = chatManager.groupChats.filter { hiddenGroupChats.contains($0.id ?? "") }
        
        if searchText.isEmpty {
            return visibleChats
        } else {
            // Include both visible and hidden chats in the search results
            return (visibleChats + hiddenChats).filter { groupChat in
                displayName(for: groupChat).localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// Extracted Subview for Header
struct HeaderView: View {
    var chatManager: ChatManager

    var body: some View {
        Text(chatManager.groupChats.isEmpty ? "No Chats" : "Chats")
            .font(.title)
            .fontWeight(.bold)
            .padding()
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// Extracted Subview for Search Bar
struct SearchBar: View {
    @Binding var searchText: String

    var body: some View {
        HStack {
            TextField("Search group chats...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.leading, 8)
                .padding(.vertical, 8)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 8)
            }
        }
    }
}

// Extracted Subview for Group Chat Row
struct GroupChatRow: View {
    var groupChat: GroupChat
    var isHidden: Bool
    var hideAction: () -> Void
    var unhideAction: () -> Void
    var displayName: String

    var body: some View {
        HStack {
            NavigationLink(destination: GroupChatView(groupId: groupChat.id ?? "")) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
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

                    if let unreadCount = groupChat.unreadCount, unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
            }

            Button(action: {
                isHidden ? unhideAction() : hideAction()
            }) {
                Image(systemName: isHidden ? "eye.fill" : "minus.circle.fill")
                    .foregroundColor(isHidden ? .green : .red)
                    .font(.title2)
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
