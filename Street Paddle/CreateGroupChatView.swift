import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CreateGroupChatView: View {
    @State private var groupName = ""
    @State private var usernames = ""
    @State private var errorMessage = ""
    @State private var isGroupCreated = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            TextField("Usernames (comma separated)", text: $usernames)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(5.0)
                .padding(.horizontal, 20)

            TextField("Group Name (2+ people)", text: $groupName)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(5.0)
                .padding(.horizontal, 20)
                .disabled(usernames.split(separator: ",").count <= 1) // Disable if only one username

            Button(action: createChat) {
                Text(usernames.split(separator: ",").count > 1 ? "Create Group Chat" : "Create Direct Chat")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 220, height: 60)
                    .background(Color.green)
                    .cornerRadius(15.0)
            }
            .padding(.top, 20)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .navigationTitle("Create Chat")
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
            let currentUserID = Auth.auth().currentUser?.uid ?? ""

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
                    // Successfully created the chat, navigate back to InboxGroupView
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

#Preview {
    CreateGroupChatView()
}
