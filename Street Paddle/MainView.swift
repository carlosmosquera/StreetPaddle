import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainView: View {
    @Binding var isUserAuthenticated: Bool
    @State private var name: String = ""
    @State private var unreadMessagesCount: Int = 0
    @State private var unreadAnnouncementsCount: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                Image(.court)
                    .resizable()
                    .opacity(0.3)
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                VStack() {
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
                    
                    NavigationLink(destination: InboxGroupView()) {
                        HStack {
                            Text("💬")
                            Text("Messages")
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
                        Text("🥇")
                        Link("Tournaments", destination: URL(string: "https://streetpaddle.co/tournaments/")!)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200.0, height: 45.0)
                    .background(Color.indigo)
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

                VStack {
                    HStack {
                        Text(name)
                            .font(.system(size: 26.0))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                    }

                    HStack {
                        Spacer()

                        Button(action: logOut) {
                            Text("Log Out")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding([.bottom,.top, .trailing])
                        }
                    }
                    Spacer()
                }
                .padding([.bottom, .trailing], 12.0)
            }
            .onAppear {
                fetchName()
                fetchUnreadMessagesCount()
                fetchUnreadAnnouncementsCount()
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

    func fetchUnreadMessagesCount() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()

        db.collection("messages")
            .whereField("receiverId", isEqualTo: user.uid)
            .whereField("isRead", isEqualTo: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching unread messages: \(error.localizedDescription)")
                    return
                }

                self.unreadMessagesCount = snapshot?.documents.count ?? 0
            }
    }
    
    func fetchUnreadAnnouncementsCount() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        // Use a reasonable default timestamp (Unix epoch start date)
        let defaultTimestamp = Timestamp(date: Date(timeIntervalSince1970: 0))
        
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching last read timestamp: \(error.localizedDescription)")
                return
            }
            
            var lastReadTimestamp: Timestamp = defaultTimestamp
            if let document = document, document.exists {
                lastReadTimestamp = document.get("lastReadAnnouncementsTimestamp") as? Timestamp ?? defaultTimestamp
            }
            
            db.collection("publicMessages")
                .whereField("timestamp", isGreaterThan: lastReadTimestamp)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching public messages: \(error.localizedDescription)")
                    } else {
                        self.unreadAnnouncementsCount = snapshot?.documents.count ?? 0
                    }
                }
        }
    }
}

#Preview {
    MainView(isUserAuthenticated: .constant(true))
}
