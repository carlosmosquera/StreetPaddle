import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PublicMessagesView: View {
    @State private var message = ""
    @State private var groupedMessages = [String: [PublicMessage]]()
    
    var body: some View {
        ZStack {
            Image(.court)
                .resizable()
                .opacity(0.3)
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            VStack {
//                Text("Public Messages")
//                    .font(.largeTitle)
//                    .fontWeight(.bold)
//                    .padding(.top, 10)
                
                Text("This space is meant for public communication only. Please use direct messages with the (username) provided for private responses.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                
                ScrollView {
                    VStack {
                        ForEach(groupedMessages.keys.sorted(by: >), id: \.self) { date in
                            Section(header: Text(date)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                        .background(Color.green)
                                        .cornerRadius(10)
                                       ){
                                ForEach(groupedMessages[date] ?? []) { message in
                                    VStack() {
                                        Text("\(message.senderName) (@\(message.senderUsername))")  // Display the name and username
                                            .font(.subheadline)
                                            .foregroundColor(.black)
                                            .multilineTextAlignment(.leading)
                                        
                                        Text(message.content)
                                            .font(.body)
                                            .padding(10)
                                            .background(Color.blue)
                                            .cornerRadius(10)
                                            .shadow(radius: 3)
                                        
                                        Text(message.timestamp.dateValue(), formatter: timeFormatter)
                                            .font(.caption)
                                            .foregroundColor(.black)
                                            .padding(.bottom, 5)
                                    }
                                    .padding(5)
                                    .frame(width: 360.0)
                                    .background(Color.white)
                                    .cornerRadius(15)
                                    .shadow(radius: 1)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                HStack {
                    TextField("Enter your message", text: $message)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minHeight: 30)
                        .padding()
                    
                    Button(action: sendMessage) {
                        Text("Send")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(15)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear(perform: fetchMessages)
            .navigationTitle("Public Messages")
        }
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
                print("Error fetching sender information: \(error.localizedDescription)")
                return
            }
            guard let document = document, document.exists, let data = document.data(), let name = data["name"] as? String, let username = data["username"] as? String else {
                print("Error fetching sender information")
                return
            }
            
            db.collection("publicMessages").addDocument(data: [
                "content": message,
                "timestamp": Timestamp(date: Date()),
                "senderName": name,
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
    var senderName: String
    var senderUsername: String  // Added this line
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
