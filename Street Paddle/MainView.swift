import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainView: View {
    @Binding var isUserAuthenticated: Bool
    @State private var name: String = ""
    @State private var unreadMessagesCount: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                Image(.court)
                    .resizable()
                    .opacity(0.3)
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                VStack {
                    Spacer().frame(width: 0, height: 0.0, alignment: .topLeading)

                    Text("STREET PADDLE")
                        .frame(height: 0.0)
                        .offset(x: 0.0, y: -80.0)
                        .font(.custom("Longhaul", size: 45))

                    NavigationLink(destination: PublicMessagesView()) {
                        HStack {
                            Text("📢")
                            Text("Announcements")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200.0, height: 45.0)
                        .background(Color.green)
                        .cornerRadius(15.0)
                    }

//                    NavigationLink(destination: InboxView()) {
//                        HStack {
//                            Text("💬")
//                            Text("DMs")
//                            if unreadMessagesCount > 0 {
//                                Text("\(unreadMessagesCount)")
//                                    .font(.subheadline)
//                                    .foregroundColor(.white)
//                                    .padding(5)
//                                    .background(Color.red)
//                                    .cornerRadius(10)
//                            }
//                        }
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .padding()
//                        .frame(width: 200.0, height: 45.0)
//                        .background(Color.orange)
//                        .cornerRadius(15.0)
//                    }
//                    
                    
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

                    NavigationLink(destination: Shop()) {
                        HStack {
                            Text("👕")
                            Text("Shop")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
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

                    NavigationLink(destination: TournamentsView()) {
                        HStack {
                            Text("🎾")
                            Text("Tournaments")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200.0, height: 45.0)
                        .background(Color.blue)
                        .cornerRadius(15.0)
                    }
                    
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
                }

                VStack {
                    HStack {
                        Text(name)
                            .font(.system(size: 26.0))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    HStack {
                        Spacer()
                        Button(action: logOut) {
                            Text("Log Out")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                        }
                        .background(Color.clear)
                        .contentShape(Rectangle())
                    }
                    Spacer()
                }
                .padding()
            }
            .onAppear {
                fetchName()
                fetchUnreadMessagesCount()
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
}

#Preview {
    MainView(isUserAuthenticated: .constant(true))
}
