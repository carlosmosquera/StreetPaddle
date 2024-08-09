import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct InboxGroupView: View {
    @State private var groupChats = [GroupChat]()
    @State private var selectedGroupId: String?

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(groupChats) { groupChat in
                        NavigationLink(
                            destination: GroupChatView(groupId: groupChat.id ?? ""),
                            tag: groupChat.id ?? "",
                            selection: $selectedGroupId
                        ) {
                            HStack {
                                Text(groupChat.name)
                                    .font(.headline)
                                Spacer()
                                Text("New messages") // Placeholder for notifications
                                    .foregroundColor(.gray)
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
                    .onDelete(perform: deleteGroupChat) // Add delete functionality
                }
                .navigationTitle("Inbox")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: CreateGroupChatView()) {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
                .onAppear(perform: fetchGroupChats)
            }
        }
    }

    func fetchGroupChats() {
        let db = Firestore.firestore()
        guard let userId = Auth.auth().currentUser?.uid else { return }

        db.collection("groups")
            .whereField("members", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching groups: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.groupChats = documents.compactMap { document -> GroupChat? in
                    try? document.data(as: GroupChat.self)
                }
            }
    }

    func deleteGroupChat(at offsets: IndexSet) {
        // Local deletion only
        offsets.forEach { index in
            // Remove the group chat from the local array
            groupChats.remove(atOffsets: offsets)
        }
    }
}

// Struct to represent a Group Chat
struct GroupChat: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
}

#Preview {
    InboxGroupView()
}
