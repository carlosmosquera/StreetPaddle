import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CheckInView: View {
    @State private var availabilityDuration = ""
    @State private var level = "Open"
    @State private var preferredPlay = "Singles"
    @State private var showConfirmation = false
    @State private var checkIns = [CheckIn]()

    var body: some View {
        VStack {
            // Form to input availability
            Form {
                Section(header: Text("Availability Check-In")) {
                    TextField("How long will you be available?", text: $availabilityDuration)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()

                    Picker("Select your level", selection: $level) {
                        Text("Open").tag("Open")
                        Text("A1").tag("A1")
                        Text("A2").tag("A2")
                        Text("Beginner").tag("Beginner")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()

                    Picker("Preferred play", selection: $preferredPlay) {
                        Text("Singles").tag("Singles")
                        Text("Doubles").tag("Doubles")
                        Text("Both").tag("Both")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()

                    Button(action: submitCheckIn) {
                        Text("Check In")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    .disabled(availabilityDuration.isEmpty)
                }
            }
            .padding(.top, 20)
            
            // List of current check-ins
            List(checkIns) { checkIn in
                VStack(alignment: .leading) {
                    Text(checkIn.userName)
                        .font(.headline)
                    Text("Available for: \(checkIn.availabilityDuration)")
                    Text("Level: \(checkIn.level)")
                    Text("Play: \(checkIn.preferredPlay)")
                    Text(checkIn.timestamp.dateValue(), formatter: dateFormatter)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            .onAppear(perform: fetchCheckIns)
        }
        .alert(isPresented: $showConfirmation) {
            Alert(title: Text("Check-In Successful"), message: Text("Your availability has been posted!"), dismissButton: .default(Text("OK")))
        }
    }

    func submitCheckIn() {
        guard let user = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        let checkInData: [String: Any] = [
            "userId": user.uid,
            "userName": user.displayName ?? "Unknown",
            "availabilityDuration": availabilityDuration,
            "level": level,
            "preferredPlay": preferredPlay,
            "timestamp": Timestamp(date: Date())
        ]
        
        db.collection("checkIns").addDocument(data: checkInData) { error in
            if let error = error {
                print("Error submitting check-in: \(error.localizedDescription)")
            } else {
                showConfirmation = true
                availabilityDuration = ""
                fetchCheckIns()
            }
        }
    }

    func fetchCheckIns() {
        let db = Firestore.firestore()
        db.collection("checkIns")
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching check-ins: \(error.localizedDescription)")
                } else {
                    checkIns = snapshot?.documents.compactMap { document in
                        try? document.data(as: CheckIn.self)
                    } ?? []
                }
            }
    }

    func removeExpiredCheckIns() {
        let db = Firestore.firestore()
        let now = Date()
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        
        db.collection("checkIns")
            .whereField("timestamp", isLessThan: Timestamp(date: midnight))
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching expired check-ins: \(error.localizedDescription)")
                } else {
                    for document in snapshot!.documents {
                        document.reference.delete()
                    }
                }
            }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()



struct CheckIn: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var userName: String
    var availabilityDuration: String
    var level: String
    var preferredPlay: String
    var timestamp: Timestamp
}


#Preview {
    CheckInView()
}
