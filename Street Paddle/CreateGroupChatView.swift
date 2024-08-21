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
                .onChange(of: usernames) { newValue in
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
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
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
            guard let currentUserID = Auth.auth().currentUser?.uid else {
                errorMessage = "Current user not authenticated."
                return
            }

            var chatData: [String: Any] = [
                "members": [currentUserID] + memberIds,
                "createdAt": Timestamp()
            ]

            if usernamesArray.count > 1 {
                // It's a group chat, include the group name
                chatData["name"] = groupName.isEmpty ? "Unnamed Group" : groupName
            } else {
                // It's a direct chat, set the name to the other user's username
                chatData["name"] = usernamesArray.first ?? "Chat"
            }

            db.collection("groups").addDocument(data: chatData) { error in
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    // Successfully created the chat, update chat list and navigate back
                    chatManager.fetchGroupChats() // Refresh the chat list
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

#Preview {
    CreateGroupChatView(chatManager: ChatManager())
}
