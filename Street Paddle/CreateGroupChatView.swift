import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CreateGroupChatView: View {
    @State private var groupName = ""
    @State private var usernames = ""
    @State private var errorMessage = ""
    @State private var isGroupCreated = false
    @State private var suggestedUsers = [String]()
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var chatManager: ChatManager

    var body: some View {
        VStack {
            // Usernames TextField with suggestions
            TextField("@usernames (comma separated)", text: $usernames)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(5.0)
                .padding(.horizontal, 20)
                .autocapitalization(.none) // Disable capitalization
                .disableAutocorrection(true) // Disable autocorrection
                .onChange(of: usernames) { oldValue, newValue in
                    usernames = newValue.lowercased() // Force lowercase
                    fetchUserSuggestions(query: newValue)
                }


            // List of suggested users
            if !suggestedUsers.isEmpty {
                List(suggestedUsers, id: \.self) { user in
                    Text(user)
                        .foregroundColor(.blue) // Set suggestion text color to blue
                        .onTapGesture {
                            selectUsername(user)
                        }
                }
                .frame(height: 100) // Adjust height as needed
            }

            // Group Name TextField
            TextField("Group Name (2+ people)", text: $groupName)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(5.0)
                .padding(.horizontal, 20)
                .onTapGesture {
                    suggestedUsers = [] // Clear suggestions when the Group Name field is tapped
                }
                .disabled(usernames.split(separator: ",").count <= 1) // Disable if only one username

            // Create Chat Button
            Button(action: createChat) {
                Text(usernames.split(separator: ",").count > 1 ? "Create Group Chat" : "Create Direct Chat")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 220, height: 60)
                    .background(createChatButtonColor)
                    .cornerRadius(15.0)
            }
            .padding(.top, 20)
            .disabled(!canCreateChat) // Disable button based on the conditions

            // Error message display

            // Error message display
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity) // Allow the text to take the maximum available width
                    .fixedSize(horizontal: false, vertical: true) // Allow the text to expand vertically
            }


        }
        .padding()
        .navigationTitle("Create Chat")
    }

    private var canCreateChat: Bool {
        let usernamesArray = usernames.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let isGroup = usernamesArray.count > 1
        return !usernamesArray.isEmpty && (!isGroup || !groupName.isEmpty)
    }

    private var createChatButtonColor: Color {
        canCreateChat ? Color.green : Color.gray
    }

    func fetchUserSuggestions(query: String) {
        let trimmedQuery = query.split(separator: ",").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmedQuery.isEmpty else {
            suggestedUsers = []
            return
        }

        let db = Firestore.firestore()

        db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: trimmedQuery)
            .whereField("username", isLessThanOrEqualTo: trimmedQuery + "\u{f8ff}")
            .limit(to: 10)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching user suggestions: \(error.localizedDescription)")
                    return
                }

                suggestedUsers = snapshot?.documents.compactMap { $0.get("username") as? String } ?? []
            }
    }

    func selectUsername(_ username: String) {
        // Split the current usernames by comma, remove whitespace, and add the selected username
        var usernamesArray = usernames.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let lastIndex = usernamesArray.indices.last {
            usernamesArray[lastIndex] = username
        } else {
            usernamesArray.append(username)
        }

        // Update the TextField with the selected username
        usernames = usernamesArray.joined(separator: ", ")

        // Clear suggestions after selecting a username
        suggestedUsers = []
    }

    func createChat() {
        let db = Firestore.firestore()
        let usernamesArray = usernames.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        guard !usernamesArray.isEmpty else {
            errorMessage = "Usernames cannot be empty."
            return
        }
        
        // Check if a chat with the same users already exists
        db.collection("groups")
            .whereField("recipientUsernames", isEqualTo: usernamesArray)
            .getDocuments { snapshot, error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }

                // If a chat exists, show error message and return
                if let documents = snapshot?.documents, !documents.isEmpty {
                    errorMessage = "A chat with these users already exists, use the search bar instead. Unhide the chat if hidden."
                    return
                }
                
                // Proceed with chat creation if no existing chat was found
                db.collection("users").whereField("username", in: usernamesArray).getDocuments { snapshot, error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        errorMessage = "No users found with the provided usernames."
                        return
                    }

                    let memberIds = documents.map { $0.documentID }
                    let recipientUsernames = documents.compactMap { $0.data()["username"] as? String }
                    guard let currentUserID = Auth.auth().currentUser?.uid else {
                        errorMessage = "Current user not authenticated."
                        return
                    }

                    db.collection("users").document(currentUserID).getDocument { userDoc, error in
                        if let error = error {
                            errorMessage = error.localizedDescription
                            return
                        }

                        let creatorUsername = userDoc?.data()?["username"] as? String ?? "Unknown"
                        
                        // Prepare the chat data
                        var chatData: [String: Any] = [
                            "members": [currentUserID] + memberIds,
                            "creatorUserID": currentUserID,
                            "creatorUsername": creatorUsername,
                            "recipientUsernames": recipientUsernames,
                            "createdAt": Timestamp(),
                            "latestMessage": "",
                            "latestMessageTimestamp": Timestamp()
                        ]

                        if usernamesArray.count > 1 {
                            chatData["groupChatName"] = groupName.isEmpty ? "Unnamed Group" : groupName
                        } else {
                            chatData["directChatName"] = usernamesArray.first ?? "Chat"
                        }

                        // Save the chat to Firestore
                        db.collection("groups").addDocument(data: chatData) { error in
                            if let error = error {
                                errorMessage = error.localizedDescription
                            } else {
                                chatManager.fetchGroupChats()
                                self.presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }
            }
    }
}

#Preview {
    CreateGroupChatView(chatManager: ChatManager())
}
