    import SwiftUI
    import FirebaseAuth
    import FirebaseFirestore

    struct GroupChatView: View {
        var groupId: String
        @State private var messageText = ""
        @State private var groupMessages = [GroupMessage]()
        @State private var userNames = [String]()
        @State private var keyboardHeight: CGFloat = 0
        @Namespace private var scrollNamespace
        @State private var textEditorHeight: CGFloat = 60

        var body: some View {
            ZStack {
                Image(.court)
                    .resizable()
                    .opacity(0.3)
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                VStack {
                    // Header with user names
                    VStack {
                        HStack {
                            Text(userNames.joined(separator: ", "))
                                .font(.headline)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(10)
                        .padding(.top, 10)
                    }

                    // Chat messages view
                    ScrollViewReader { scrollView in
                        ScrollView {
                            VStack(alignment: .leading) {
                                ForEach(groupMessages) { message in
                                    VStack(alignment: .leading) {
                                        HStack {
                                            if message.senderId == Auth.auth().currentUser?.uid {
                                                Spacer()
                                                VStack(alignment: .trailing) {
                                                    Text(message.text)
                                                        .padding()
                                                        .background(Color.blue)
                                                        .cornerRadius(8)
                                                        .foregroundColor(.white)
                                                        .id(message.id)
                                                    
                                                    Text(message.timestamp.dateValue(), formatter: messageTimeFormatter)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .padding(.top, 2)
                                                    
                                                    Text(message.senderName ?? "Unknown")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }
                                            } else {
                                                VStack(alignment: .leading) {
                                                    Text(message.text)
                                                        .padding()
                                                        .background(Color.gray.opacity(0.2))
                                                        .cornerRadius(8)
                                                        .id(message.id)
                                                    
                                                    Text(message.timestamp.dateValue(), formatter: messageTimeFormatter)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .padding(.top, 2)
                                                    
                                                    Text(message.senderName ?? "Unknown")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            .padding(.top)
                        }
                        .padding(.top, 10)
                        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
                        .onChange(of: groupMessages) { _ in
                            scrollToEnd(scrollView)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                            scrollToEnd(scrollView)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                            scrollToEnd(scrollView)
                        }
                    }

                    Spacer()

                    // Message input area
                    HStack(alignment: .center) { // Center alignment for the button
                        TextEditor(text: $messageText)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(5.0)
                            .frame(height: textEditorHeight)
                            .onChange(of: messageText) { _ in
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
                        .disabled(messageText.isEmpty)
                        .frame(height: textEditorHeight) // Ensure the button takes the full height of the TextEditor
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    .padding(.bottom, keyboardHeight)
                    
                    .animation(.easeOut(duration: 0.16))
                    .offset(x: /*@START_MENU_TOKEN@*/5.0/*@END_MENU_TOKEN@*/, y: /*@START_MENU_TOKEN@*/-10.0/*@END_MENU_TOKEN@*/)
                }
                .onAppear {
                    fetchGroupData()
                    subscribeToKeyboardEvents()
                }
                .onDisappear {
                    unsubscribeFromKeyboardEvents()
                }
            }
        }
        
        // Existing functions like fetchGroupData, sendMessage, subscribeToKeyboardEvents, etc.
        
        func fetchGroupData() {
            let db = Firestore.firestore()
            
            db.collection("groups").document(groupId).getDocument { document, error in
                if let error = error {
                    print("Error fetching group details: \(error)")
                    return
                }
                
                guard let data = document?.data(), let memberIds = data["members"] as? [String] else {
                    print("Group data is missing or malformed.")
                    return
                }
                
                db.collection("users").whereField(FieldPath.documentID(), in: memberIds).getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching user names: \(error)")
                        return
                    }
                    
                    let userNameDict = snapshot?.documents.reduce(into: [String: String]()) { dict, document in
                        if let name = document.data()["name"] as? String {
                            dict[document.documentID] = name
                        }
                    }
                    
                    self.userNames = memberIds.compactMap { userNameDict?[$0] }
                    
                    db.collection("groups").document(groupId).collection("groupmessages")
                        .order(by: "timestamp")
                        .addSnapshotListener { snapshot, error in
                            if let error = error {
                                print("Error fetching messages: \(error)")
                                return
                            }
                            
                            guard let documents = snapshot?.documents else { return }
                            
                            self.groupMessages = documents.compactMap { document -> GroupMessage? in
                                var message = try? document.data(as: GroupMessage.self)
                                if let senderId = message?.senderId {
                                    message?.senderName = userNameDict?[senderId]
                                }
                                return message
                            }
                        }
                }
            }
        }
        
        func sendMessage() {
            let db = Firestore.firestore()
            guard !messageText.isEmpty else { return }
            
            // Add the message to the group chat
            db.collection("groups").document(groupId).collection("groupmessages").addDocument(data: [
                "senderId": Auth.auth().currentUser?.uid ?? "",
                "text": messageText,
                "timestamp": Timestamp()
            ]) { error in
                if let error = error {
                    print("Error sending message: \(error)")
                }
            }
            
            // Update the latest message and timestamp in the group chat document
            db.collection("groups").document(groupId).updateData([
                "latestMessage": messageText,
                "latestMessageTimestamp": Timestamp()
            ]) { error in
                if let error = error {
                    print("Error updating latest message: \(error)")
                }
            }
            
            messageText = ""
            textEditorHeight = 60 // Reset the height after sending a message
        }

        private func subscribeToKeyboardEvents() {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    self.keyboardHeight = keyboardFrame.height / 2
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
        
        private func scrollToEnd(_ scrollView: ScrollViewProxy) {
            if let lastMessageId = groupMessages.last?.id {
                withAnimation {
                    scrollView.scrollTo(lastMessageId, anchor: .bottom)
                }
            }
        }
        
        private func adjustTextEditorHeight() {
            let size = CGSize(width: UIScreen.main.bounds.width - 100, height: .infinity)
            let estimatedSize = NSString(string: messageText).boundingRect(
                with: size,
                options: .usesLineFragmentOrigin,
                attributes: [.font: UIFont.systemFont(ofSize: 16)],
                context: nil
            )
            
            let newHeight = max(80, min(estimatedSize.height + 30, 150))
            textEditorHeight = newHeight
        }
    }



    private let messageTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    #Preview {
        GroupChatView(groupId: "exampleGroupId")
    }
