import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PublicMessagesView: View {
    @State private var message = ""
    @State private var messages = [PublicMessage]()

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(messages) { message in
                        VStack(alignment: .leading) {
                            Text(message.senderUsername)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text(message.content)
                                .font(.body)
                                .padding(10)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                                .padding(.bottom, 5)
                        }
                        .padding(5)
                    }
                }
                .padding()
            }
            
            HStack {
                TextField("Enter your message", text: $message)
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
        .onAppear(perform: fetchMessages)
        .navigationTitle("Public Messages")
    }

    func fetchMessages() {
        let db = Firestore.firestore()
        db.collection("publicMessages")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching public messages: \(error.localizedDescription)")
                } else {
                    messages = snapshot?.documents.compactMap { document in
                        try? document.data(as: PublicMessage.self)
                    } ?? []
                }
            }
    }

    func sendMessage() {
        guard let user = Auth.auth().currentUser else { return }

        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching sender username: \(error.localizedDescription)")
                return
            }
            guard let document = document, document.exists, let data = document.data(), let username = data["username"] as? String else {
                print("Error fetching username")
                return
            }

            db.collection("publicMessages").addDocument(data: [
                "content": message,
                "timestamp": Timestamp(date: Date()),
                "senderUsername": username
            ]) { error in
                if let error = error {
                    print("Error sending message: \(error.localizedDescription)")
                } else {
                    message = ""
                }
            }
        }
    }
}

struct PublicMessage: Identifiable, Codable {
    @DocumentID var id: String?
    var content: String
    var timestamp: Timestamp
    var senderUsername: String
}

#Preview {
    PublicMessagesView()
}
