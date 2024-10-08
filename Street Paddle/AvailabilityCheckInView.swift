import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AvailabilityCheckInView: View {
    @State private var selectedDuration = "30 min"
    @State private var selectedLevel = "Open"
    @State private var selectedGameType = "Singles"
    @State private var availabilityList = [Availability]()

    let durationOptions = ["30 min", "1 hour", "2 hours", "3 hours", "4 hours", "5 hours", "6 hours", "Not sure"]
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
                Text("Only use this when you are at the courts so other players can see who's around.")
                    .font(.headline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()

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
                            Text("\(availability.userName) (@\(availability.username))")
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
                print("Error fetching user data")
                return
            }
            
            let username = user.email?.components(separatedBy: "@").first ?? "Unknown"
            
            let newAvailability = Availability(
                id: nil,
                userId: user.uid,
                userName: name,
                username: username,
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
                    guard var availability = try? document.data(as: Availability.self) else { return nil }
                    
                    // Automatically delete expired availability
                    if isExpired(availability: availability) {
                        deleteAvailability(availability: availability)
                        return nil
                    }
                    
                    availability.id = document.documentID
                    return availability
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
    
    func durationToTimeInterval(duration: String) -> TimeInterval {
        switch duration {
        case "30 min":
            return 30 * 60
        case "1 hour":
            return 60 * 60
        case "2 hours":
            return 2 * 60 * 60
        case "3 hours":
            return 3 * 60 * 60
        case "4 hours":
            return 4 * 60 * 60
        case "5 hours":
            return 5 * 60 * 60
        case "6 hours":
            return 6 * 60 * 60
        default:
            return 0 // "Not sure" case or any other unspecified duration
        }
    }
    
    func isExpired(availability: Availability) -> Bool {
        let interval = durationToTimeInterval(duration: availability.duration)
        let expirationDate = availability.timestamp.dateValue().addingTimeInterval(interval)
        return Date() > expirationDate
    }
}

// Availability model


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
