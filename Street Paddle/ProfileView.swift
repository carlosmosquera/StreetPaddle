import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ProfileView: View {
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var relationshipStatus: String = ""
    @State private var playerLevel: String = ""
    @State private var location: String = ""
    @State private var isEditing: Bool = false
    
    var userId: String
    
    var body: some View {
        VStack {
            Text("Profile")
                .font(.largeTitle)
                .padding()

            Form {
                Section(header: Text("Basic Information")) {
                    Text("Name: \(name)")
                    Text("Username: \(username)")
                }
                
                Section(header: Text("Editable Information")) {
                    if isEditing {
                        TextField("Relationship Status", text: $relationshipStatus)
                        TextField("Player Level", text: $playerLevel)
                        TextField("Location", text: $location)
                    } else {
                        Text("Relationship Status: \(relationshipStatus)")
                        Text("Player Level: \(playerLevel)")
                        Text("Location: \(location)")
                    }
                }
                
                if Auth.auth().currentUser?.uid == userId {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveProfileData()
                        }
                        isEditing.toggle()
                    }
                }
            }
        }
        .onAppear(perform: fetchProfileData)
    }
    
    func fetchProfileData() {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                self.name = data?["name"] as? String ?? ""
                self.username = data?["username"] as? String ?? ""
                self.relationshipStatus = data?["relationshipStatus"] as? String ?? ""
                self.playerLevel = data?["playerLevel"] as? String ?? ""
                self.location = data?["location"] as? String ?? ""
            }
        }
    }
    
    func saveProfileData() {
        guard let currentUserId = Auth.auth().currentUser?.uid, currentUserId == userId else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).setData([
            "relationshipStatus": relationshipStatus,
            "playerLevel": playerLevel,
            "location": location
        ], merge: true) { error in
            if let error = error {
                print("Error updating profile: \(error)")
            }
        }
    }
}
