import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PublicMessagesView: View {
    @State private var message = ""
    @State private var groupedMessages = [String: [PublicMessage]]()
    @State private var currentUsername: String = ""
    @State private var friends = Set<String>() // Track friends
    @State private var textEditorHeight: CGFloat = 60 // Initial height for the TextEditor
    @State private var keyboardHeight: CGFloat = 0 // Track keyboard height
    @State private var showToast = false // Track whether to show the toast message
    @State private var toastMessage = "" // The message to show in the toast

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
                                                    .foregroundColor(.blue)
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
                
                // Message input area
                HStack(alignment: .bottom) {
                    TextEditor(text: $message)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(5.0)
                        .frame(height: textEditorHeight)
                        .onChange(of: message) { _ in
                            adjustTextEditorHeight()
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 10)
                    .disabled(message.isEmpty) // Disable if message is empty
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .padding(.bottom, keyboardHeight) // Adjust for keyboard height
                .animation(.easeOut(duration: 0.16)) // Animate the change in padding
            }
            .onAppear {
                fetchMessages()
                fetchCurrentUser()
                fetchFriends() // Fetch friends on appear
                updateLastReadTimestamp() // Mark announcements as read
                subscribeToKeyboardEvents()
            }
            .onDisappear {
                unsubscribeFromKeyboardEvents()
            }
            .navigationTitle("Public Messages")

            // Toast message
            if showToast {
                VStack {
                    Spacer()

                    Text(toastMessage)
                        .font(.body)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    showToast = false
                                }
                            }
                        }
                }
                .zIndex(1) // Ensure the toast is above other content
            }
        }
    }

    // Function to update the last read timestamp when the view appears
    func updateLastReadTimestamp() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(user.uid).updateData([
            "lastReadAnnouncementsTimestamp": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("Error updating last read timestamp: \(error.localizedDescription)")
            } else {
                print("Last read timestamp updated successfully")
            }
        }
    }
    
    // Remaining functions (fetchMessages, sendMessage, fetchCurrentUser, etc.) remain the same
    // ...


    
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
                    textEditorHeight = 60 // Reset the height after sending a message
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
                
                // Show toast message
                showToastMessage("User added to your friends list")
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

    // MARK: - Toast Message Handling
    func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showToast = false
            }
        }
    }

    // MARK: - Keyboard Handling
    private func subscribeToKeyboardEvents() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self.keyboardHeight = keyboardFrame.height / 2 - 35 // Adjust height for keyboard
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            self.keyboardHeight = 0
        }
    }

    private func unsubscribeFromKeyboardEvents() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func adjustTextEditorHeight() {
        let size = CGSize(width: UIScreen.main.bounds.width - 100, height: .infinity) // Adjusted width to account for padding and button
        let estimatedSize = NSString(string: message).boundingRect(
            with: size,
            options: .usesLineFragmentOrigin,
            attributes: [.font: UIFont.systemFont(ofSize: 16)],
            context: nil
        )
        
        let newHeight = max(80, min(estimatedSize.height + 30, 150)) // Ensure it doesn't shrink below initial height
        textEditorHeight = newHeight
    }
}


#Preview {
    PublicMessagesView()
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
