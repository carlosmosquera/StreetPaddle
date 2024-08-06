import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainView: View {
    @Binding var isUserAuthenticated: Bool
    @State private var username: String = ""

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
                    
//                    Image(.spLogoWhite)
//                        .aspectRatio(contentMode: .fill)
//                        .ignoresSafeArea()
//                        .padding()
//                        .offset(x: 0.0, y: -80.0)

                    NavigationLink(destination: PublicMessagesView()) {

                        HStack() {
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

                    NavigationLink(destination: InboxView()) {
                        HStack {

                            Text("💬")
                            Text("DMs")

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
                            Text("Merch")
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
                }

                VStack {

                    HStack {                       
//                        Spacer()
                        Text(username)
                            .font(.system(size: 26.0))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
//                            .padding()
//                            .ignoresSafeArea()
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
                fetchUsername()
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

    func fetchUsername() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let document = document, document.exists, let data = document.data(), let fetchedUsername = data["username"] as? String {
                self.username = fetchedUsername
            } else {
                print("User does not exist or failed to fetch username")
            }
        }
    }
}

#Preview {
    MainView(isUserAuthenticated: .constant(true))
}
