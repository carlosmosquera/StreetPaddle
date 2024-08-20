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
    @State private var textEditorHeight: CGFloat = 60 // Initial height for the TextEditor
    @Environment(\.presentationMode) var presentationMode // To control the navigation

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
//                        Button(action: {
//                            // Custom back action
//                            if let navigationController = UIApplication.shared.windows.first?.rootViewController as? UINavigationController {
//                                navigationController.popViewController(animated: true)
//                            }
//                        }) {
//                            Image(systemName: "arrow.left")
//                                .foregroundColor(.blue)
//                                .padding()
//                        }

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
                    .padding(.top, 10) // Adjust top padding to reduce space
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
                                                    .id(message.id) // Assign unique ID to each message
                                                
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
                                                    .id(message.id) // Assign unique ID to each message
                                                
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
                        .padding(.top) // Padding to prevent content from entering the safe area
                    }
                    .padding(.top, 10) // Ensure there's a padding to keep content within safe area
                    .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) } // Respect the safe area
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
                
                Spacer() // Push the TextEditor and Send button to the bottom

                // Message input area
                HStack(alignment: .bottom) {
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
                    .disabled(messageText.isEmpty) // Disable if message is empty
                }
                .padding(.horizontal)
                .padding(.bottom, 10) // Add some padding at the bottom to keep it close to the keyboard
                .padding(.bottom, keyboardHeight) // Adjust padding by keyboard height
                .animation(.easeOut(duration: 0.16)) // Animate the change in padding
            }
            .onAppear {
                fetchGroupData()
                subscribeToKeyboardEvents()
            }
            .onDisappear {
                unsubscribeFromKeyboardEvents()
            }
        }
//        .navigationBarBackButtonHidden(true) // Hide the default back button
    }
    



    


    
    func fetchGroupData() {
        let db = Firestore.firestore()
        
        // Fetch group details to get member IDs
        db.collection("groups").document(groupId).getDocument { document, error in
            if let error = error {
                print("Error fetching group details: \(error)")
                return
            }
            
            guard let data = document?.data(), let memberIds = data["members"] as? [String] else {
                print("Group data is missing or malformed.")
                return
            }
            
            // Fetch names for all members
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
                
                // Update user names for the header
                self.userNames = memberIds.compactMap { userNameDict?[$0] }
                
                // Fetch group messages
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
                            // Set the sender's name
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
        
        db.collection("groups").document(groupId).collection("groupmessages").addDocument(data: [
            "senderId": Auth.auth().currentUser?.uid ?? "",
            "text": messageText,
            "timestamp": Timestamp()
        ]) { error in
            if let error = error {
                print("Error sending message: \(error)")
            }
        }
        
        messageText = ""
        textEditorHeight = 60 // Reset the height after sending a message
    }
    
    // MARK: - Keyboard Handling

    private func subscribeToKeyboardEvents() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self.keyboardHeight = keyboardFrame.height / 2 - 35 // Subtract some height to get closer to the keyboard
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
        let size = CGSize(width: UIScreen.main.bounds.width - 100, height: .infinity) // Adjusted width to account for padding and button
        let estimatedSize = NSString(string: messageText).boundingRect(
            with: size,
            options: .usesLineFragmentOrigin,
            attributes: [.font: UIFont.systemFont(ofSize: 16)],
            context: nil
        )
        
        let newHeight = max(80, min(estimatedSize.height + 30, 150)) // Ensure it doesn't shrink below initial height
        textEditorHeight = newHeight
    }
}

// Define the GroupMessage struct with Equatable conformance
struct GroupMessage: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    var timestamp: Timestamp
    var senderName: String?

    static func == (lhs: GroupMessage, rhs: GroupMessage) -> Bool {
        return lhs.id == rhs.id
    }
}

// Date formatter for message timestamps
private let messageTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    GroupChatView(groupId: "exampleGroupId")
}
