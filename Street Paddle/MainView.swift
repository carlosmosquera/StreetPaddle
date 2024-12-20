import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UserNotifications

struct MainView: View {
    @Binding var isUserAuthenticated: Bool
    @State private var name: String = ""
    @State private var unreadMessagesCount: Int = 0
    @State private var unreadAnnouncementsCount: Int = 0
    @State private var profileImage: UIImage? = nil
    @ObservedObject var chatManager = ChatManager() // Observing the ChatManager for real-time chat updates
    @State private var isAdmin: Bool = false
    @State private var announcementListener: ListenerRegistration? // For managing the listener registration
    @State private var messagesListener: ListenerRegistration? // For managing real-time message updates
    
    var body: some View {
        NavigationView {
            ZStack {
                Image(.court)
                    .resizable()
                    .opacity(0.3)
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                
                VStack {
                    VStack {
                        NavigationLink(destination: ProfileView(isUserAuthenticated: $isUserAuthenticated, userId: Auth.auth().currentUser?.uid ?? "")) {
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .scaledToFit() // Use scaledToFit to maintain aspect ratio
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                                    .shadow(radius: 5)
                            } else {
                                Image(systemName: "person.circle")
                                    .resizable()
                                    .frame(width: 50, height: 50)
                            }
                        }


                        
                        HStack {
                            Spacer()
                            Button(action: logOut) {
                                Text("Log Out")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding([.bottom, .top, .trailing])
                            }
                        }
                    }
                    
                    Spacer().frame(width: 0, height: 0.0, alignment: .topLeading)
                    
                    Text("STREET PADDLE")
                        .frame(height: 0.0)
                        .offset(x: 0.0, y: 25.0)
                        .font(.custom("Longhaul", size: 45))
                    
                    // Announcements button with badge
                    NavigationLink(destination: PublicMessagesView()) {
                        HStack {
                            Text("📢")
                            Text("Announcements")
                            
                            // Show badge if there are unread announcements
                            if unreadAnnouncementsCount > 0 {
                                Text("\(unreadAnnouncementsCount)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200.0, height: 45.0)
                        .background(Color.green)
                        .cornerRadius(15.0)
                        .padding(.top, 80)
                    }
                    
                    // Messages button with badge for unread messages
                    NavigationLink(destination: InboxGroupView(chatManager: chatManager)) {
                        HStack {
                            Text("💬")
                            Text("Messages")
                            
                            if unreadMessagesCount > 0 {
                                Text("\(unreadMessagesCount)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200.0, height: 45.0)
                        .background(Color.orange)
                        .cornerRadius(15.0)
                    }
                    
                    // Friends, Tournaments, and other buttons
                    NavigationLink(destination: FriendsListView()) {
                        HStack {
                            Text("👫")
                            Text("Friends")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200.0, height: 45.0)
                        .background(Color.cyan)
                        .cornerRadius(15.0)
                    }
                    
                    // Only show Tournament Setup button for admins
                    if isAdmin {
                        NavigationLink(destination: TournamentSetupView()) {
                            HStack {
                                Text("⚙️")
                                Text("Tournament Setup")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 200.0, height: 45.0)
                            .background(Color.indigo)
                            .cornerRadius(15.0)
                        }
                    }
                    
                    NavigationLink(destination: TournamentDrawView()) {
                        HStack {
                            Text("🥇")
                            Text("Tournaments")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200.0, height: 45.0)
                        .background(Color.indigo)
                        .cornerRadius(15.0)
                    }
                    
                    VStack(spacing: 60) {
                        NavigationLink(destination: AvailabilityCheckInView()) {
                            HStack {
                                Text("📍")
                                Text("Check In")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 200.0, height: 45.0)
                            .background(Color.brown)
                            .cornerRadius(15.0)
                        }
                        
                        HStack {
                            Text("👕")
                            Link("Shop", destination: URL(string: "https://streetpaddle1.myshopify.com/collections/all")!)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200.0, height: 45.0)
                        .background(Color.blue)
                        .cornerRadius(15.0)
                    }
                    
                    HStack {
                        Text("📹")
                        Link("Live Cam", destination: URL(string: "https://hdontap.com/stream/956353/venice-beach-live/")!)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200.0, height: 45.0)
                    .background(Color.red)
                    .cornerRadius(15.0)
                    
                    HStack {
                        Text("🎾")
                        Link("Lessons", destination: URL(string: "https://streetpaddle.co/classes/")!)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200.0, height: 45.0)
                    .background(Color.mint)
                    .cornerRadius(15.0)
                }
                .padding([.bottom, .trailing], 12.0)
            }
            .onAppear {
                resetAppBadge()
                fetchName()
                fetchProfileImage()
                listenForUnreadMessages()  // Start real-time updates for unread messages
                listenForUnreadAnnouncements()  // Start listening for real-time updates
                checkIfAdmin() // Check if the user is an admin
            }
            .onDisappear {
                stopListeningForUnreadMessages() // Stop listening for message updates
                stopListeningForUnreadAnnouncements() // Stop listening when view disappears
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    func listenForUnreadMessages() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        messagesListener = db.collection("groups")
            .whereField("members", arrayContains: user.uid)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching group messages: \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.global(qos: .background).async { // Handle updates in the background
                    var totalUnread = 0
                    
                    let dispatchGroup = DispatchGroup() // Ensure all unread counts are fetched before updating the badge
                    
                    snapshot?.documents.forEach { document in
                        let groupId = document.documentID
                        dispatchGroup.enter() // Enter the group before each fetch
                        self.fetchUnreadCount(for: groupId) { unreadCount in
                            totalUnread += unreadCount
                            dispatchGroup.leave() // Leave when done
                        }
                    }
                    
                    // Wait for all fetches to finish
                    dispatchGroup.notify(queue: .main) {
                        self.unreadMessagesCount = totalUnread
                        self.updateAppBadge()  // Update the badge once all counts are processed
                    }
                }
            }
    }

    // Fetch unread count for each group chat
    func fetchUnreadCount(for groupChatId: String, completion: @escaping (Int) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        let userLastReadDocRef = db.collection("groups").document(groupChatId).collection("members").document(userId)
        
        userLastReadDocRef.getDocument { document, error in
            if let error = error {
                print("Error fetching last read timestamp: \(error)")
                completion(0)
                return
            }
            
            guard let document = document, let lastReadTimestamp = document.data()?["lastReadTimestamp"] as? Timestamp else {
                completion(0)
                return
            }
            
            db.collection("groups").document(groupChatId).collection("groupmessages")
                .whereField("timestamp", isGreaterThan: lastReadTimestamp)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching unread messages: \(error)")
                        completion(0)
                        return
                    }
                    
                    let unreadCount = snapshot?.documents.count ?? 0
                    completion(unreadCount)
                }
        }
    }
    
    // Stop listening to messages when the view disappears
    func stopListeningForUnreadMessages() {
        messagesListener?.remove()
    }
    
    // Real-time listener for unread announcements
    func listenForUnreadAnnouncements() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                let lastReadTimestamp = document.get("lastReadAnnouncementsTimestamp") as? Timestamp ?? Timestamp(date: Date(timeIntervalSince1970: 0))
                
                announcementListener = db.collection("publicMessages")
                    .whereField("timestamp", isGreaterThan: lastReadTimestamp)
                    .addSnapshotListener { snapshot, error in
                        if let error = error {
                            print("Error fetching public messages: \(error.localizedDescription)")
                            return
                        }
                        
                        DispatchQueue.global(qos: .background).async {
                            let unreadMessages = snapshot?.documents ?? []
                            DispatchQueue.main.async {
                                self.unreadAnnouncementsCount = unreadMessages.count
                                self.updateAppBadge()  // Real-time badge update
                            }
                        }
                    }
            }
        }
    }

    // Stop listening to announcements when the view disappears
    func stopListeningForUnreadAnnouncements() {
        announcementListener?.remove()
    }
    

    func updateAppBadge() {
        let totalUnread = unreadMessagesCount + unreadAnnouncementsCount
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else { return }
                
                // Update the badge count on the app icon
                UNUserNotificationCenter.current().setBadgeCount(totalUnread) { error in
                    if let error = error {
                        print("Error updating badge count: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // Reset app icon badge when app is opened
    func resetAppBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("Error resetting badge count: \(error.localizedDescription)")
            }
        }
    }

    
    func logOut() {
        do {
            try Auth.auth().signOut()
            isUserAuthenticated = false
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
    
    func fetchName() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let document = document, document.exists, let data = document.data(), let fetchedName = data["name"] as? String {
                self.name = fetchedName
            } else {
                print("User does not exist or failed to fetch name")
            }
        }
    }
    
    func fetchProfileImage() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists, let data = document.data(), let imageUrl = data["profileImageUrl"] as? String {
                self.loadImageFromUrl(url: imageUrl)
            } else {
                print("User document does not exist or imageUrl not found")
            }
        }
    }

    func loadImageFromUrl(url: String) {
        guard !url.isEmpty else { return }
        
        // Check if the URL is a full Firebase Storage URL or just a path
        let storageRef: StorageReference
        if url.starts(with: "gs://") || url.starts(with: "https://") {
            storageRef = Storage.storage().reference(forURL: url)
        } else {
            storageRef = Storage.storage().reference().child(url) // Assuming it's a relative path
        }

        storageRef.getData(maxSize: 2 * 1024 * 1024) { data, error in
            if let error = error {
                print("Error loading image: \(error)")
                return
            }
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profileImage = uiImage
                }
            }
        }
    }

    func checkIfAdmin() {
        guard let user = Auth.auth().currentUser else { return }
        let allowedEmails = ["carlosmosquera.r@gmail.com", "avillaronga96@gmail.com"]
        let db = Firestore.firestore()
        
        db.collection("users").document(user.uid).getDocument { document, error in
            if let document = document, document.exists, let email = document.data()?["email"] as? String {
                self.isAdmin = allowedEmails.contains(email)
            }
        }
    }
}
