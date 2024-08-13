import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PublicMessagesView: View {
    @State private var message = ""
    @State private var groupedMessages = [String: [PublicMessage]]()
    @State private var currentUsername: String = ""
    @State private var friends = Set<String>() // Track friends

    var body: some View {
        ZStack {
            Image(.court)
                .resizable()
                .opacity(0.3)
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            VStack {
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
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("\(message.senderName) (@\(message.senderUsername))")
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
                                        .background(Color.white)
                                        .cornerRadius(15)
                                        .shadow(radius: 1)
                                        
                                        // Show icon based on friend status
                                        if message.senderUsername != currentUsername {
                                            Button(action: {
                                                if friends.contains(message.senderUsername) {
                                                    // Remove friend
                                                    removeFriend(username: message.senderUsername)
                                                } else {
                                                    // Add friend
                                                    validateAndAddFriend(username: message.senderUsername)
                                                }
                                            }) {
                                                Image(systemName: friends.contains(message.senderUsername) ? "checkmark.circle.fill" : "plus.circle.fill")
                                                    .foregroundColor(friends.contains(message.senderUsername) ? .blue : .green)
                                                    .padding()
                                            }
                                        }
                                    }
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
            .onAppear {
                fetchMessages()
                fetchCurrentUser()
                fetchFriends() // Fetch friends on appear
            }
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
    
    func fetchCurrentUser() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            if let document = document, document.exists {
                self.currentUsername = document.get("username") as? String ?? ""
            }
        }
    }

    func fetchFriends() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching friends: \(error.localizedDescription)")
                return
            }
            if let document = document, document.exists {
                self.friends = Set(document.get("friends") as? [String] ?? [])
            }
        }
    }

    func validateAndAddFriend(username: String) {
        let db = Firestore.firestore()
        let usersRef = db.collection("users")
        
        usersRef.whereField("username", isEqualTo: username).getDocuments { snapshot, error in
            if let error = error {
                print("Error validating user: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot, !snapshot.isEmpty else {
                print("User not found, not adding to friends list")
                return
            }
            
            // User exists, proceed to add to friends list
            addFriend(username: username)
        }
    }

    func addFriend(username: String) {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        userRef.updateData([
            "friends": FieldValue.arrayUnion([username])
        ]) { error in
            if let error = error {
                print("Error adding friend: \(error.localizedDescription)")
            } else {
                // Update local state after adding friend
                self.friends.insert(username)
                print("\(username) added as friend")
            }
        }
    }
    
    func removeFriend(username: String) {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        userRef.updateData([
            "friends": FieldValue.arrayRemove([username])
        ]) { error in
            if let error = error {
                print("Error removing friend: \(error.localizedDescription)")
            } else {
                // Update local state after removing friend
                self.friends.remove(username)
                print("\(username) removed from friends list")
                
                // Notify FriendsListView about the change
                DispatchQueue.main.async {
                    fetchFriends() // Refresh friends list to ensure UI update
                }
            }
        }
    }
}


#Preview {
    PublicMessagesView()
}

struct PublicMessage: Identifiable, Codable {
    @DocumentID var id: String?
    var content: String
    var timestamp: Timestamp
    var senderName: String
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
