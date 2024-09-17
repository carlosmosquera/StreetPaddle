import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct MainView: View {
    @Binding var isUserAuthenticated: Bool
    @State private var name: String = ""
    @State private var unreadMessagesCount: Int = 0
    @State private var unreadAnnouncementsCount: Int = 0
    @State private var profileImage: UIImage? = nil
    @ObservedObject var chatManager = ChatManager() // Add this line to observe the ChatManager
    @State private var isAdmin: Bool = false

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
                        NavigationLink(destination: ProfileView(userId: Auth.auth().currentUser?.uid ?? "")) {
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
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
                    
                    NavigationLink(destination: PublicMessagesView()) {
                        HStack {
                            Text("📢")
                            Text("Announcements")
                            
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
                    
                    NavigationLink(destination: InboxGroupView(chatManager: chatManager)) {
                        HStack {
                            Text("💬")
                            Text("Messages")
                            
                            if chatManager.totalUnreadCount > 0 {
                                Text("\(chatManager.totalUnreadCount)")
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
                        Link("Live Cam", destination: URL(string: "https://hdontap.com/stream/322247/venice-beach-surf-cam/")!)
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
                fetchName()
                fetchProfileImage()
                chatManager.fetchGroupChats()
                fetchUnreadAnnouncementsCount()
                checkIfAdmin() // Check if the user is an admin
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
            if let document = document, document.exists, let data = document.data(), let imageUrl = data["profileImageUrl"] as? String {
                loadImageFromUrl(url: imageUrl)
            }
        }
    }

    func loadImageFromUrl(url: String) {
        let storageRef = Storage.storage().reference(forURL: url)
        storageRef.getData(maxSize: 2 * 1024 * 1024) { data, error in
            if let error = error {
                print("Error loading image: \(error)")
                return
            }
            if let data = data, let uiImage = UIImage(data: data) {
                self.profileImage = uiImage
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
    
    func fetchUnreadAnnouncementsCount() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(user.uid).getDocument { document, error in
            if let document = document, document.exists {
                let lastReadTimestamp = document.get("lastReadAnnouncementsTimestamp") as? Timestamp ?? Timestamp(date: Date(timeIntervalSince1970: 0))
                db.collection("publicMessages").whereField("timestamp", isGreaterThan: lastReadTimestamp).getDocuments { snapshot, error in
                    self.unreadAnnouncementsCount = snapshot?.documents.count ?? 0
                }
            }
        }
    }
}
