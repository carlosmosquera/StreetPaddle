import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ChatView: View {
    let recipientUsername: String
    @State private var newMessage = ""
    @State private var messages = [PrivateMessage]()
    @State private var senderUsername = ""

    var body: some View {
        VStack {
            List(messages) { message in
                VStack(alignment: .leading) {
                    Text(message.senderUsername)
                        .font(.subheadline)
                        .foregroundColor(message.senderUsername == senderUsername ? .blue : .gray)
                    Text(message.content)
                        .font(.body)
                        .padding(10)
                        .background(message.senderUsername == senderUsername ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity, alignment: message.senderUsername == senderUsername ? .trailing : .leading)
                }
                .padding(5)
            }

            HStack {
                TextField("Enter your message", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 30)

                Button(action: sendMessage) {
                    Text("Send")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(15)
                }
            }
            .padding()
        }
        .navigationTitle(recipientUsername)
        .onAppear(perform: fetchMessages)
    }

    func fetchMessages() {
        guard let user = Auth.auth().currentUser else { return }

        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching sender: \(error.localizedDescription)")
                return
            }
            guard let document = document, document.exists, let data = document.data(), let username = data["username"] as? String else {
                print("Sender does not have a username")
                return
            }
            senderUsername = username

            db.collection("privateMessages")
                .whereField("senderUsername", in: [username, recipientUsername])
                .whereField("recipientID", in: [user.uid, getRecipientID(username: recipientUsername)])
                .order(by: "timestamp", descending: false)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error fetching messages: \(error.localizedDescription)")
                    } else {
                        messages = snapshot?.documents.compactMap { document in
                            try? document.data(as: PrivateMessage.self)
                        } ?? []
                    }
                }
        }
    }

    func sendMessage() {
        guard let user = Auth.auth().currentUser else { return }

        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching sender: \(error.localizedDescription)")
            } else {
                guard let document = document, document.exists, let data = document.data(), let username = data["username"] as? String else {
                    print("Sender does not have a username")
                    return
                }
                let recipientID = getRecipientID(username: recipientUsername)

                db.collection("privateMessages").addDocument(data: [
                    "content": newMessage,
                    "timestamp": Timestamp(date: Date()),
                    "senderUsername": username,
                    "recipientID": recipientID
                ]) { error in
                    if let error = error {
                        print("Error sending message: \(error.localizedDescription)")
                    } else {
                        newMessage = ""
                    }
                }
            }
        }
    }

    func getRecipientID(username: String) -> String {
        let db = Firestore.firestore()
        var recipientID = ""
        db.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error finding recipient: \(error.localizedDescription)")
                } else if snapshot?.isEmpty == true {
                    print("Recipient not found")
                } else {
                    guard let document = snapshot?.documents.first else {
                        print("Recipient not found")
                        return
                    }
                    recipientID = document.documentID
                }
            }
        return recipientID
    }
}

struct PrivateMessage: Identifiable, Codable {
    @DocumentID var id: String?
    var content: String
    var timestamp: Timestamp
    var senderUsername: String
    var recipientID: String
}

#Preview {
    ChatView(recipientUsername: "Carlos")
}
