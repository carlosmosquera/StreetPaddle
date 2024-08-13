import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FriendsListView: View {
    @State private var friends = [String]()
    @State private var isNavigatingToChat = false
    @State private var newChatId: String?
    @State private var selectedFriend: String?

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(friends, id: \.self) { friend in
                        HStack {
                            Text(friend)
                                .font(.headline)
                                .padding(.leading)
                                .onTapGesture {
                                    selectedFriend = friend
                                    openOrCreateChat(with: friend)
                                }
                            
                            Spacer()
                            
                            Button(action: {
                                removeFriend(username: friend)
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
            .background(
                NavigationLink(
                    destination: InboxGroupView(selectedGroupId: newChatId),
                    isActive: $isNavigatingToChat
                ) {
                    EmptyView()
                }
            )
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
                self.friends = document.get("friends") as? [String] ?? []
            }
        }
    }

    func openOrCreateChat(with friend: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        // Check if a direct chat already exists between the two users
        db.collection("groups")
            .whereField("members", arrayContains: currentUserId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching chats: \(error.localizedDescription)")
                    return
                }

                let existingChat = snapshot?.documents.first(where: { document in
                    let members = document.get("members") as? [String] ?? []
                    return members.contains(friend) && members.count == 2
                })

                if let chat = existingChat {
                    // If the chat already exists, navigate to it
                    self.newChatId = chat.documentID
                    self.isNavigatingToChat = true
                } else {
                    // If no chat exists, create a new one
                    createNewChat(with: friend)
                }
            }
    }

    func createNewChat(with friend: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        // Find the friend's user ID based on their username
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

                // Create the chat with the friend
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
                        // After creating the chat, navigate to the chat view
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
                // Update local state after removing friend
                self.friends.removeAll { $0 == username }
                print("\(username) removed from friends list")
                
                // Notify PublicMessagesView about the change
                DispatchQueue.main.async {
                    fetchFriends() // Refresh friends list to ensure UI update
                }
            }
        }
    }
}
