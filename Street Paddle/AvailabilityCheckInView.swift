import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AvailabilityCheckInView: View {
    @State private var selectedDuration = "30 min"
    @State private var selectedLevel = "Open"
    @State private var selectedGameType = "Singles"
    @State private var availabilityList = [Availability]()

    let durationOptions = ["30 min", "60 min", "90 min", "2 hours", "3 hours", "4 hours", "5 hours", "6 hours", "Not sure"]
    let levelOptions = ["Open", "A1", "A2", "Beginner"]
    let gameTypeOptions = ["Singles", "Doubles", "Both"]

    var body: some View {
        ZStack {
            Image(.court)
                .resizable()
                .opacity(0.3)
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            VStack {
                Form {
                    Section(header: Text("Availability")) {
                        Picker("Duration", selection: $selectedDuration) {
                            ForEach(durationOptions, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())

                        Picker("Level", selection: $selectedLevel) {
                            ForEach(levelOptions, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        Picker("Game Type", selection: $selectedGameType) {
                            ForEach(gameTypeOptions, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Button(action: checkIn) {
                        Text("Check In")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                .frame(height: 290.0)
                
                List {
                    ForEach(availabilityList) { availability in
                        VStack(alignment: .leading) {
                            Text("\(availability.userName) (\(Auth.auth().currentUser?.email ?? ""))")
                                .font(.headline)
                                .foregroundColor(Color.black)
                            Text("Duration: \(availability.duration)")
                                .foregroundColor(Color.black)
                            Text("Level: \(availability.level)")
                                .foregroundColor(Color.black)
                            Text("\(availability.gameType)")
                                .foregroundColor(Color.black)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .swipeActions {
                            if availability.userId == Auth.auth().currentUser?.uid {
                                Button(role: .destructive) {
                                    deleteAvailability(availability: availability)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .onAppear(perform: fetchAvailability)
            }
        }
    }
    
    func checkIn() {
        guard let user = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists, let data = document.data(), let name = data["name"] as? String else {
                print("Error fetching user name")
                return
            }
            
            let newAvailability = Availability(
                id: nil,
                userId: user.uid,
                userName: name,
                duration: selectedDuration,
                level: selectedLevel,
                gameType: selectedGameType,
                timestamp: Timestamp(date: Date())
            )
            
            db.collection("availability").addDocument(data: newAvailability.toDictionary()) { error in
                if let error = error {
                    print("Error checking in: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func fetchAvailability() {
        let db = Firestore.firestore()
        
        db.collection("availability")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching availability: \(error.localizedDescription)")
                    return
                }
                
                availabilityList = snapshot?.documents.compactMap { document in
                    try? document.data(as: Availability.self)
                } ?? []
            }
    }
    
    func deleteAvailability(availability: Availability) {
        guard let id = availability.id else { return }
        let db = Firestore.firestore()
        db.collection("availability").document(id).delete { error in
            if let error = error {
                print("Error deleting availability: \(error.localizedDescription)")
            }
        }
    }
}

// Availability model
struct Availability: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var userName: String
    var duration: String
    var level: String
    var gameType: String
    var timestamp: Timestamp
    
    func toDictionary() -> [String: Any] {
        return [
            "userId": userId,
            "userName": userName,
            "duration": duration,
            "level": level,
            "gameType": gameType,
            "timestamp": timestamp
        ]
    }
}

// Date formatter for availability timestamps
private let availabilityTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    AvailabilityCheckInView()
}
