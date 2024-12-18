import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

struct ProfileView: View {
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var relationshipStatus: String = ""
    @State private var playerLevel: String = ""
    @State private var location: String = ""
    @State private var handedness: String = ""
    @State private var isEditing: Bool = false
    @State private var isCurrentUser: Bool = false
    @State private var profileImage: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @State private var imageUrl: String = ""
    @Binding var isUserAuthenticated: Bool // Binding to manage authentication state
    var userId: String
    @State private var showDeleteConfirmation: Bool = false // State variable for alert

    var body: some View {
        VStack {
            Text("Profile")
                .font(.largeTitle)
                .padding()

            // Profile Image Section
            ZStack {
                if let profileImage = profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray, lineWidth: 4))
                        .shadow(radius: 10)
                        .padding()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .padding()
                }

                // Tap overlay
                if isCurrentUser {
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Circle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 150, height: 150)
                            .overlay(
                                Text("Edit")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage, onImagePicked: uploadImageToStorage)
            }

            // Profile Information
            Form {
                Section(header: Text("Basic Information")) {
                    Text("Name: \(name)")
                    Text("Username: \(username)")
                }

                Section(header: Text("Information")) {
                    if isEditing && isCurrentUser {
                        TextField("Relationship Status", text: $relationshipStatus)
                        TextField("Player Level", text: $playerLevel)
                        TextField("Location", text: $location)
                        Picker("Handedness", selection: $handedness) {
                            Text("Right-handed").tag("Right-handed")
                            Text("Left-handed").tag("Left-handed")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    } else {
                        Text("Relationship Status: \(relationshipStatus)")
                        Text("Player Level: \(playerLevel)")
                        Text("Location: \(location)")
                        Text("Handedness: \(handedness)")
                    }
                }

                // Edit Profile Button
                if isCurrentUser {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveProfileData()
                        }
                        isEditing.toggle()
                    }
                }

                // Delete Account Button
                if isCurrentUser {
                    Button(action: {
                        showDeleteConfirmation = true // Show confirmation alert
                    }) {
                        Text("Delete Account")
                            .foregroundColor(.red)
                    }
                    .alert(isPresented: $showDeleteConfirmation) {
                        Alert(
                            title: Text("Delete Account"),
                            message: Text("Are you sure you want to delete your account? This action cannot be undone."),
                            primaryButton: .destructive(Text("Delete")) {
                                deleteAccount() // Call delete function on confirmation
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
        }
        .onAppear(perform: fetchProfileData)
    }
    
    // Fetch profile data from Firestore
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
                self.handedness = data?["handedness"] as? String ?? ""
                self.imageUrl = data?["profileImageUrl"] as? String ?? ""
                loadImageFromUrl(url: imageUrl)
            }
        }

        // Check if the current user is viewing their own profile
        if let currentUserId = Auth.auth().currentUser?.uid {
            isCurrentUser = (currentUserId == userId)
        }
    }
    
    // Save profile data to Firestore
    func saveProfileData() {
        guard let currentUserId = Auth.auth().currentUser?.uid, currentUserId == userId else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).setData([
            "relationshipStatus": relationshipStatus,
            "playerLevel": playerLevel,
            "location": location,
            "handedness": handedness,
            "profileImageUrl": imageUrl
        ], merge: true) { error in
            if let error = error {
                print("Error updating profile: \(error)")
            }
        }
    }
    
    // Delete Account
    func deleteAccount() {
        guard let currentUser = Auth.auth().currentUser else { return }

        let db = Firestore.firestore()
        
        db.collection("users").document(currentUser.uid).delete { error in
            if let error = error {
                print("Error deleting Firestore document: \(error.localizedDescription)")
            } else {
                print("Firestore document successfully deleted")
            }
            
            currentUser.delete { error in
                if let error = error {
                    print("Error deleting account: \(error.localizedDescription)")
                } else {
                    do {
                        try Auth.auth().signOut()
                        isUserAuthenticated = false
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // Upload the image to Firebase Storage
    func uploadImageToStorage(image: UIImage) {
        let resizedImage = image.resized(toWidth: 1024)

        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else { return }
        
        let storageRef = Storage.storage().reference().child("profileImages/\(userId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        storageRef.putData(imageData, metadata: metadata) { (metadata, error) in
            if let error = error {
                print("Error uploading image: \(error)")
                return
            }
            storageRef.downloadURL { (url, error) in
                if let error = error {
                    print("Error getting image URL: \(error)")
                    return
                }
                if let url = url {
                    self.imageUrl = url.absoluteString
                    self.saveProfileData()
                }
            }
        }
    }

    // Load the image from Firebase Storage
    func loadImageFromUrl(url: String) {
        guard !url.isEmpty else { return }
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
}
