import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PrivateMessagesView: View {
    @State private var recipientUsername = ""
    @State private var errorMessage = ""
    @State private var chatRecipient: String? = nil

    var body: some View {
        VStack {
            TextField("Recipient Username", text: $recipientUsername)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(5.0)
                .padding(.bottom, 20)

            Button(action: checkRecipient) {
                Text("Start Chat")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 220, height: 60)
                    .background(Color.blue)
                    .cornerRadius(15.0)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            NavigationLink(destination: ChatView(recipientUsername: chatRecipient ?? ""), isActive: Binding<Bool>(
                get: { chatRecipient != nil },
                set: { if !$0 { chatRecipient = nil } }
            )) {
                EmptyView()
            }
        }
        .padding()
    }

    func checkRecipient() {
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("username", isEqualTo: recipientUsername)
            .getDocuments { snapshot, error in
                if let error = error {
                    errorMessage = "Error finding recipient: \(error.localizedDescription)"
                } else if snapshot?.isEmpty == true {
                    errorMessage = "Recipient not found"
                } else {
                    chatRecipient = recipientUsername
                    errorMessage = ""
                }
            }
    }
}


#Preview {
    PrivateMessagesView()
}
