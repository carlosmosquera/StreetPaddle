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
    @State private var isEditing: Bool = false
    
    @State private var profileImage: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @State private var imageUrl: String = ""
    
    var userId: String
    
    var body: some View {
        VStack {
            Text("Profile")
                .font(.largeTitle)
                .padding()

            // Profile Image Section
            if let profileImage = profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray, lineWidth: 4))
                    .shadow(radius: 10)
                    .padding()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .padding()
            }

            if Auth.auth().currentUser?.uid == userId {
                Button("Change Profile Picture") {
                    showImagePicker.toggle()
                }
            }

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
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage, onImagePicked: uploadImageToStorage)
        }
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
                self.imageUrl = data?["profileImageUrl"] as? String ?? ""
                loadImageFromUrl(url: imageUrl)
            }
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
            "profileImageUrl": imageUrl
        ], merge: true) { error in
            if let error = error {
                print("Error updating profile: \(error)")
            }
        }
    }
    
    // Upload the image to Firebase Storage and store the URL in Firestore
    func uploadImageToStorage(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
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
                    self.saveProfileData() // Save the image URL along with other data
                }
            }
        }
    }
    
    // Load the image from Firebase Storage using the URL
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
