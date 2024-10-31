import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PublicMessagesView: View {
    @State private var message = ""
    @State private var groupedMessages = [String: [PublicMessage]]()
    @State private var currentUsername: String = ""
    @State private var friends = Set<String>()
    @State private var textEditorHeight: CGFloat = 50
    @State private var keyboardHeight: CGFloat = 0
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var newChatId: String? = nil
    @State private var isNavigatingToChat = false
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        //        NavigationStack {
        GeometryReader { geometry in
            ZStack {
                Image(.court)
                    .resizable()
                    .opacity(0.3)
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                
                VStack {
                    headerView
                    
                    ScrollViewReader { scrollView in
                        ScrollView {
                            VStack {
                                // Sort dates descending to show the latest date sections first
                                ForEach(groupedMessages.keys.sorted(by: >), id: \.self) { date in
                                    Section(header: dateHeaderView(date: date)) {
                                        ForEach(groupedMessages[date] ?? []) { message in
                                            messageItemView(message: message)
                                                .id(message.id) // Attach message ID for finer scrolling
                                        }
                                    }
                                    .id(date) // Attach section ID for scrolling to the header
                                }
                            }
                        }
                        .padding(.horizontal)
                        .onAppear {
                            scrollToTop(scrollView) // Scroll to the top when the view loads
                        }
                        .onChange(of: groupedMessages) {
                            scrollToTop(scrollView) // Scroll to the top when new messages arrive
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { _ in
                            scrollToTop(scrollView) // Scroll to the top when receiving the notification
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                            scrollToTop(scrollView) // Scroll to the top when the keyboard shows
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                            scrollToTop(scrollView) // Scroll to the top when the keyboard hides
                        }
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .center) {
                 
                            TextEditor(text: $message)
                                .padding(8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(5.0)
                                .frame(height: textEditorHeight)
                                .onChange(of: message) {
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
                        .padding(.leading, 10)
                        .disabled(message.isEmpty)
                        .frame(height: textEditorHeight)

                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    .padding(.bottom, keyboardHeight)
                    .animation(.easeOut(duration: 0.16), value: keyboardHeight)
                }
                .frame(width: geometry.size.width)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                
                .onAppear {
                    fetchMessages()
                    fetchCurrentUser()
                    fetchFriends()
                    updateLastReadTimestamp()
                    resetNotificationCount()
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
        .navigationDestination(isPresented: $isNavigatingToChat) {
            if let groupId = newChatId {
                GroupChatView(groupId: groupId)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        
        .navigationViewStyle(StackNavigationViewStyle())
    }
//}
    // MARK: - Helper Methods


    private func scrollToTop(_ scrollView: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let firstSectionKey = groupedMessages.keys.sorted(by: >).first {
                withAnimation {
                    scrollView.scrollTo(firstSectionKey, anchor: .top)
                }
            }
        }
    }



    private func subscribeToKeyboardEvents() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self.keyboardHeight = keyboardFrame.height - 40
                print("Debug: Keyboard will show. Height: \(self.keyboardHeight)")
            }
        }

        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            self.keyboardHeight = 0
            print("Debug: Keyboard will hide.")
        }
    }

    private func unsubscribeFromKeyboardEvents() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
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

    // MARK: - Helper Views and Functions
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
            // Profile image navigation link
            NavigationLink(destination: ProfileView(userId: message.senderId)) {
                // Display the profile image if available
                if let profileImageUrl = message.profileImageUrl, let url = URL(string: profileImageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 30, height: 30) // Match profile image size
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 30, height: 30) // Reduced the size of profile image
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                        case .failure:
                            // Default icon if loading fails
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 30, height: 30) // Reduced size of default icon
                                .clipShape(Circle())
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // Default icon if no profile image is available
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30) // Reduced size of default icon
                        .clipShape(Circle())
                        .foregroundColor(.gray)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Button to open or create group chat
                    Button(action: {
                        openOrCreateChat(with: message.senderUsername)
                    }) {
                        Text("\(message.senderName) (@\(message.senderUsername))")
                            .font(.footnote) // Smaller font
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .underline()
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()
                    Text(message.timestamp.dateValue(), formatter: timeFormatter)
                        .font(.caption2) // Smaller font for timestamp
                        .foregroundColor(.gray)
                }

                // Announcements Styling
                Text(message.content)
                    .font(.footnote) // Smaller font for message content
                    .padding(8) // Reduced padding for message bubble
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8) // Reduced corner radius for bubble
                    .foregroundColor(.black)

                // Friend Status Indicator
                HStack {
                    if friends.contains(message.senderUsername) {
                        Text("🔹 Friend").font(.caption2).foregroundColor(.green) // Smaller font
                    } else if message.senderUsername != currentUsername {
                        // Add Friend Button
                        Button(action: {
                            print("Debug: Adding \(message.senderUsername) as a friend.")
                            validateAndAddFriend(username: message.senderUsername)
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add Friend")
                                    .font(.caption2) // Smaller font
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .padding(8) // Reduced overall padding
            .background(Color.white)
            .cornerRadius(10) // Reduced corner radius
            .shadow(color: Color.gray.opacity(0.3), radius: 2, x: 1, y: 1)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 3) // Reduced vertical padding
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8) // Reduced corner radius
        .padding(.horizontal)
    }

    func openOrCreateChat(with friendUsername: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        db.collection("groups")
            .whereField("members", arrayContains: currentUserId)
            .whereField("directChatName", isEqualTo: friendUsername)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching chats: \(error.localizedDescription)")
                    return
                }

                if let chat = snapshot?.documents.first {
                    // Chat with the friend's username as the group name already exists
                    self.newChatId = chat.documentID
                    self.isNavigatingToChat = true
                } else {
                    // No chat found, create a new one
                    createNewChat(with: friendUsername)
                }
            }
    }

    func createNewChat(with friendUsername: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        db.collection("users")
            .whereField("username", isEqualTo: friendUsername)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching user: \(error.localizedDescription)")
                    return
                }

                guard let friendDoc = snapshot?.documents.first else {
                    print("No user found with username \(friendUsername)")
                    return
                }

                let friendId = friendDoc.documentID
                let creatorUsername = Auth.auth().currentUser?.displayName ?? "Unknown"

                let newChatData: [String: Any] = [
                    "members": [currentUserId, friendId],
                    "creatorUserID": currentUserId,
                    "creatorUsername": creatorUsername,
                    "recipientUsernames": [friendUsername],
                    "createdAt": Timestamp(),
                    "directChatName": friendUsername
                ]

                var newChatRef: DocumentReference? = nil
                newChatRef = db.collection("groups").addDocument(data: newChatData) { error in
                    if let error = error {
                        print("Error creating chat: \(error.localizedDescription)")
                    } else {
                        if let documentId = newChatRef?.documentID {
                            self.newChatId = documentId
                        }
                        self.isNavigatingToChat = true
                    }
                }
            }
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
                       
                       // Fetch profile image URLs for each message's sender
                       let dispatchGroup = DispatchGroup()
                       
                       for index in messages.indices {
                           dispatchGroup.enter()
                           let senderId = messages[index].senderId
                           db.collection("users").document(senderId).getDocument { document, error in
                               if let document = document, document.exists {
                                   let profileImageUrl = document.get("profileImageUrl") as? String
                                   messages[index].profileImageUrl = profileImageUrl
                               }
                               dispatchGroup.leave()
                           }
                       }
                       
                       // Once all profile images are fetched, update the groupedMessages state
                       dispatchGroup.notify(queue: .main) {
                           messages.sort { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
                           groupedMessages = Dictionary(grouping: messages, by: { message in
                               let date = message.timestamp.dateValue()
                               return dateFormatter.string(from: date)
                           })
                       }
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
            guard let document = document, document.exists,
                  let data = document.data(),
                  let name = data["name"] as? String,
                  let username = data["username"] as? String else {
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
                    // Clear the input and reset the text editor height
                    message = ""
                    textEditorHeight = 60
                    
                    // Hide the keyboard
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    
                    resetNotificationCount() // Reset notifications

                    // Post the scrollToTop notification
                    NotificationCenter.default.post(name: .scrollToTop, object: nil)
                }
            }
        }
    }

       func resetNotificationCount() {
           notificationManager.resetPublicMessagesNotificationCount()
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


    private func adjustTextEditorHeight() {
        let widthConstraint = UIScreen.main.bounds.width - 100 // Adjust based on padding or parent view constraints
        let estimatedSize = NSString(string: message).boundingRect(
            with: CGSize(width: widthConstraint, height: .infinity),
            options: .usesLineFragmentOrigin,
            attributes: [.font: UIFont.systemFont(ofSize: 16)],
            context: nil
        )
        
        // Only adjust height if the text needs more space horizontally
        if estimatedSize.width > widthConstraint {
            let newHeight = max(80, min(estimatedSize.height + 30, 150))
            textEditorHeight = newHeight
        }
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
