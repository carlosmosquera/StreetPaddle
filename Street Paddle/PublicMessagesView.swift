import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PublicMessagesView: View {
    @State private var message = ""
    @State private var groupedMessages = [String: [PublicMessage]]()
    @State private var currentUsername: String = ""
    @State private var friends = Set<String>()
    @State private var textEditorHeight: CGFloat = 60
    @State private var keyboardHeight: CGFloat = 0
    @State private var showToast = false
    @State private var toastMessage = ""
    @EnvironmentObject var notificationManager: NotificationManager // Access the NotificationManager

    var body: some View {
        ZStack {
            Image(.court)
                .resizable()
                .opacity(0.3)
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            VStack {
                headerView

                ScrollView {
                    messagesListView
                }
                .padding(.horizontal)

                messageInputView
            }
            .onAppear {
                fetchMessages()
                fetchCurrentUser()
                fetchFriends()
                updateLastReadTimestamp()
                resetNotificationCount() // Reset notifications when viewing
                subscribeToKeyboardEvents()
            }
            .onDisappear {
                unsubscribeFromKeyboardEvents()
            }
            .navigationTitle("Public Messages")

            if showToast {
                toastView
            }
        }
    }

    var headerView: some View {
        Text("📣 Announcements - Use Direct Messages for Private Responses.")
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal)
            .background(Color.blue.opacity(0.8))
            .cornerRadius(10)
            .padding(.vertical, 10)
    }

    var messagesListView: some View {
        VStack {
            ForEach(groupedMessages.keys.sorted(by: >), id: \.self) { date in
                Section(header: dateHeaderView(date: date)) {
                    ForEach(groupedMessages[date] ?? []) { message in
                        messageItemView(message: message)
                    }
                }
            }
        }
    }

    var messageInputView: some View {
        HStack(alignment: .bottom) {
            TextEditor(text: $message)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(5.0)
                .frame(height: textEditorHeight)
                .onChange(of: message) { _ in adjustTextEditorHeight() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .padding(.trailing, 10)
            .disabled(message.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .padding(.bottom, keyboardHeight)
        .animation(.easeOut(duration: 0.16))
    }

    var toastView: some View {
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
                        withAnimation { showToast = false }
                    }
                }
        }
        .zIndex(1)
    }

    func dateHeaderView(date: String) -> some View {
        Text(date)
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal)
            .background(Color.green.opacity(0.9))
            .cornerRadius(10)
    }

    func messageItemView(message: PublicMessage) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    NavigationLink(destination: ProfileView(userId: message.senderId)) {
                        Text("\(message.senderName) (@\(message.senderUsername))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .underline()
                    }
                    Spacer()
                    Text(message.timestamp.dateValue(), formatter: timeFormatter)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Announcements Styling
                Text(message.content)
                    .font(.body)
                    .padding()
                    .background(Color.blue.opacity(0.1)) // Lighter background for announcement
                    .cornerRadius(12)
                    .foregroundColor(.black)

                // Friend Status Indicator
                HStack {
                    if friends.contains(message.senderUsername) {
                        Text("🔹 Friend").font(.caption).foregroundColor(.green) // Display if friend
                    } else if message.senderUsername != currentUsername { // Check if not current user
                        Button(action: {
                            validateAndAddFriend(username: message.senderUsername)
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add Friend")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(15)
            .shadow(color: Color.gray.opacity(0.3), radius: 2, x: 1, y: 1)
            .frame(maxWidth: .infinity) // Make bubble wider
        }
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal)
    }


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
                 "senderId": user.uid,
                 "senderName": name,
                 "senderUsername": username,
                 "content": message,
                 "timestamp": Timestamp(date: Date())
             ]) { error in
                 if let error = error {
                     print("Error sending message: \(error.localizedDescription)")
                 } else {
                     message = ""
                     textEditorHeight = 60
                     resetNotificationCount() // Reset notifications on message send
                 }
             }
         }
     }
    
    func resetNotificationCount() {
           notificationManager.resetPublicMessagesNotificationCount() // Implement this in your NotificationManager
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
