import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PublicMessagesView: View {
    @State private var message = ""
    @State private var groupedMessages = [String: [PublicMessage]]()
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(groupedMessages.keys.sorted(by: >), id: \.self) { date in
                        Section(header: Text(date)
                                    .font(.headline)
                                    .foregroundColor(.white)
//                                    .padding()
                                    .padding(.horizontal)
                                    .background(Color.green)
                                    .cornerRadius(10)
                                   ){
                            ForEach(groupedMessages[date] ?? []) { message in
                                VStack(alignment: .leading) {
                                    Text(message.senderUsername)
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                        .multilineTextAlignment(.leading)
                                    Text(message.content)
                                        .font(.body)
                                        .padding(10)
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                        .shadow(radius: 3)
                                    Text(message.timestamp.dateValue(), formatter: timeFormatter)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.bottom, 5)
                                }
                                .padding(5)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                                .shadow(radius: 1)
//                                .offset(x: /*@START_MENU_TOKEN@*/-100.0/*@END_MENU_TOKEN@*/, y: /*@START_MENU_TOKEN@*/10.0/*@END_MENU_TOKEN@*/)
                            }
                        }
                                   .padding(.horizontal)
                    }
                }
                .padding()
                .frame(width: 400.0)
                
            }
            .frame(width: 400.0)
            
            HStack {
                TextField("Enter your message", text: $message)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 30)
                
                Button(action: sendMessage) {
                    Text("Send")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(15)
                }
            }
            .padding()
        }
        .background(Color("TennisBackground"))
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
                    var messages = snapshot?.documents.compactMap { document in
                        try? document.data(as: PublicMessage.self)
                    } ?? []
                    messages.sort { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
                    groupedMessages = Dictionary(grouping: messages, by: { message in
                        let date = message.timestamp.dateValue()
                        return dateFormatter.string(from: date)
                    })
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

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
}()


#Preview {
    PublicMessagesView()
}
