import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ComposeMessageView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var recipientUsername = ""
    @State private var messageText = ""
    @Binding var refreshMessages: Bool
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack {
                TextField("Recipient Username", text: $recipientUsername)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(5.0)
                    .padding([.leading, .trailing], 20)

                TextField("Message", text: $messageText)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(5.0)
                    .padding([.leading, .trailing], 20)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }

                Button(action: sendMessage) {
                    Text("Send")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 220, height: 60)
                        .background(Color.blue)
                        .cornerRadius(15.0)
                }
                .padding()
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty) // Disable button if message is empty
            }
            .navigationBarTitle("New Message", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Cancel")
            })
        }
    }

    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Message cannot be empty"
            return
        }
        
        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? ""

        // Fetch sender's username
        db.collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists, let data = document.data(), let senderUsername = data["username"] as? String {
                
                // Fetch recipient's user ID based on the entered username
                db.collection("users").whereField("username", isEqualTo: recipientUsername).getDocuments { snapshot, error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let recipientDocument = snapshot?.documents.first else {
                        errorMessage = "Recipient not found"
                        return
                    }
                    
                    let recipientId = recipientDocument.documentID
                    let recipientUsername = recipientDocument.data()["username"] as? String ?? ""

                    // Create a new message
                    let newMessage = Message(senderId: userId, senderUsername: senderUsername, receiverId: recipientId, receiverUsername: recipientUsername, text: messageText, timestamp: Timestamp(date: Date()))

                    do {
                        _ = try db.collection("messages").addDocument(from: newMessage)
                        refreshMessages = true
                        presentationMode.wrappedValue.dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } else {
                errorMessage = "Failed to fetch sender's username"
            }
        }
    }
}

#Preview {
    ComposeMessageView(refreshMessages: .constant(false))
}
