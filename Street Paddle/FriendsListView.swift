import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FriendsListView: View {
    @State private var friends = [(name: String, username: String)]()  // Store both name and username
    @State private var isNavigatingToChat = false
    @State private var newChatId: String?
    @State private var selectedFriend: String?

    @State private var searchText = ""
    @State private var suggestedUsers = [String]()
    @State private var isAddingFriend = false

    var body: some View {
        NavigationStack {
            VStack {
                // Search bar for adding new friends
                TextField("Search for users...", text: $searchText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .onChange(of: searchText) { newValue in
                        // Convert to lowercase and search for users
                        searchText = newValue.lowercased()
                        searchUsers(query: searchText)
                    }

                // List of suggested users
                if !suggestedUsers.isEmpty {
                    List(suggestedUsers, id: \.self) { user in
                        Text(user)
                            .onTapGesture {
                                addFriend(username: user)
                            }
                    }
                }

                List {
                    ForEach(friends, id: \.username) { friend in  // Use username as unique identifier
                        HStack {
                            // Text for name and username
                            Text("\(friend.name) (\(friend.username))")
                                .font(.headline)
                                .padding(.leading)
                                .onTapGesture {
                                    // Only trigger chat navigation when the text is tapped
                                    selectedFriend = friend.username
                                    openOrCreateChat(with: friend.username)
                                }

                            Spacer()

                            // Minus button for removing friend
                            Button(action: {
                                removeFriend(username: friend.username)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .onAppear(perform: fetchFriends)
            }
            .navigationTitle("Friends List")
            .navigationDestination(isPresented: $isNavigatingToChat) {
                if let chatId = newChatId {
                    GroupChatView(groupId: chatId)
                } else {
                    Text("No Chat Selected") // Fallback if chatId is nil
                }
            }
        }
    }

    func fetchFriends() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching friends: \(error.localizedDescription)")
                return
            }
            if let document = document, document.exists {
                let usernames = document.get("friends") as? [String] ?? []
                
                // Fetch the names corresponding to each username
                db.collection("users")
                    .whereField("username", in: usernames)
                    .getDocuments { snapshot, error in
                        if let error = error {
                            print("Error fetching user data: \(error.localizedDescription)")
                            return
                        }

                        self.friends = snapshot?.documents.compactMap { doc in
                            guard let name = doc.get("name") as? String,
                                  let username = doc.get("username") as? String else { return nil }
                            return (name: name, username: username)
                        } ?? []
                    }
            }
        }
    }

    func searchUsers(query: String) {
        guard !query.isEmpty else {
            suggestedUsers = []
            return
        }

        let db = Firestore.firestore()

        db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query)
            .whereField("username", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 10)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error searching for users: \(error.localizedDescription)")
                    return
                }

                if let documents = snapshot?.documents {
                    self.suggestedUsers = documents.compactMap { $0.get("username") as? String }
                    print("Suggested Users: \(self.suggestedUsers)")
                } else {
                    self.suggestedUsers = []
                }
            }
    }

    func addFriend(username: String) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUser.uid)

        userRef.updateData([
            "friends": FieldValue.arrayUnion([username])
        ]) { error in
            if let error = error {
                print("Error adding friend: \(error.localizedDescription)")
            } else {
                fetchFriends()  // Refresh the friends list to include the new friend
                self.searchText = ""
                self.suggestedUsers = []
            }
        }
    }

    func openOrCreateChat(with friend: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        db.collection("groups")
            .whereField("name", isEqualTo: friend)  // Look for a group where the name matches the friend's username
            .whereField("members", arrayContains: currentUserId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching chats: \(error.localizedDescription)")
                    return
                }

                if let chat = snapshot?.documents.first {
                    // Chat with the friend's username as the group name already exists
                    print("Chat found with friend: \(friend)")
                    self.newChatId = chat.documentID
                    self.isNavigatingToChat = true
                } else {
                    // No chat found, create a new one
                    print("No chat found with friend: \(friend). Creating new chat.")
                    createNewChat(with: friend)
                }
            }
    }

    func createNewChat(with friend: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        db.collection("users")
            .whereField("username", isEqualTo: friend)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching user: \(error.localizedDescription)")
                    return
                }

                guard let friendDoc = snapshot?.documents.first else {
                    print("No user found with username \(friend)")
                    return
                }

                let friendId = friendDoc.documentID

                let newChatData: [String: Any] = [
                    "members": [currentUserId, friendId],
                    "createdAt": Timestamp(),
                    "name": friend
                ]

                var newChatRef: DocumentReference? = nil
                newChatRef = db.collection("groups").addDocument(data: newChatData) { error in
                    if let error = error {
                        print("Error creating chat: \(error.localizedDescription)")
                    } else {
                        self.newChatId = newChatRef?.documentID
                        self.isNavigatingToChat = true
                    }
                }
            }
    }

    func removeFriend(username: String) {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        userRef.updateData([
            "friends": FieldValue.arrayRemove([username])
        ]) { error in
            if let error = error {
                print("Error removing friend: \(error.localizedDescription)")
            } else {
                self.friends.removeAll { $0.username == username }
                print("\(username) removed from friends list")
                
                DispatchQueue.main.async {
                    fetchFriends()
                }
            }
        }
    }
}

#Preview {
    FriendsListView()
}
