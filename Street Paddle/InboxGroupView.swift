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
                    Text(chatManager.groupChats.isEmpty ? "No Chats" : "Chats")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    HStack { // Search Bar
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
                    
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(filteredGroupChats) { groupChat in
                                if !hiddenGroupChats.contains(groupChat.id ?? "") { // Only show if not hidden
                                    HStack {
                                        NavigationLink(
                                            destination: GroupChatView(groupId: groupChat.id ?? "")
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
                                        }
                                        
                                        // Minus icon to hide the group chat
                                        Button(action: {
                                            hideGroupChat(groupChat: groupChat)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                                .font(.title2)
                                        }
                                        .padding(.leading, 8)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
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
    
    // Hide a group chat and save the change
    func hideGroupChat(groupChat: GroupChat) {
        if let groupId = groupChat.id {
            hiddenGroupChats.insert(groupId)
            saveHiddenGroupChats() // Save to UserDefaults
        }
    }
    
    // Load hidden group chats from UserDefaults
    func loadHiddenGroupChats() {
        if let savedChats = UserDefaults.standard.array(forKey: hiddenChatsKey) as? [String] {
            DispatchQueue.main.async {
                hiddenGroupChats = Set(savedChats)
            }
        }
    }

    
    // Save hidden group chats to UserDefaults
    func saveHiddenGroupChats() {
        UserDefaults.standard.set(Array(hiddenGroupChats), forKey: hiddenChatsKey)
    }
    
    // Filter group chats based on search text
    var filteredGroupChats: [GroupChat] {
        let visibleChats = chatManager.groupChats.filter { !hiddenGroupChats.contains($0.id ?? "") }
        if searchText.isEmpty {
            return visibleChats
        } else {
            return visibleChats.filter { groupChat in
                displayName(for: groupChat).localizedCaseInsensitiveContains(searchText)
            }
        }
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
    
    // Stop all listeners when the view disappears
    func stopListening() {
        messagesListener?.remove()
    }
    
    
    // Function to display group chat names
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
    
    // Fetch the user's name by their username
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
    
}
