import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct Tournament: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var startDate: Timestamp
    var endDate: Timestamp
    var link: String
}

struct TournamentsView: View {
    @State private var tournaments = [Tournament]()
    @State private var isAdmin = false
    @State private var editingTournament: Tournament? = nil

    var body: some View {
        VStack {
            if isAdmin {
                Button(action: addTournament) {
                    Text("Add Tournament")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(15)
                }
                .padding()
            }
            
            List {
                ForEach(tournaments) { tournament in
                    VStack(alignment: .leading) {
                        if isAdmin {
                            HStack {
                                Button(action: { editTournament(tournament) }) {
                                    Text("Edit")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(15)
                                }
                                Button(action: { deleteTournament(tournament) }) {
                                    Text("Delete")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(15)
                                }
                            }
                        }
                        Link(destination: URL(string: tournament.link)!) {
                            Text(tournament.title)
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        Text("From \(dateFormatter.string(from: tournament.startDate.dateValue())) to \(dateFormatter.string(from: tournament.endDate.dateValue()))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .onAppear(perform: fetchTournaments)
        .sheet(item: $editingTournament) { tournament in
            EditTournamentView(tournament: tournament, isEditing: true) {
                fetchTournaments()
            }
        }
        .navigationTitle("Tournaments")
    }
    
    func fetchTournaments() {
        guard let user = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            guard let document = document, document.exists, let data = document.data(), let username = data["username"] as? String else {
                print("Error fetching username")
                return
            }
            isAdmin = (username == "Admin")
        }
        
        db.collection("tournaments")
            .order(by: "startDate", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching tournaments: \(error.localizedDescription)")
                } else {
                    tournaments = snapshot?.documents.compactMap { document in
                        try? document.data(as: Tournament.self)
                    } ?? []
                }
            }
    }
    
    func addTournament() {
        editingTournament = Tournament(id: nil, title: "", startDate: Timestamp(), endDate: Timestamp(), link: "")
    }
    
    func editTournament(_ tournament: Tournament) {
        editingTournament = tournament
    }
    
    func deleteTournament(_ tournament: Tournament) {
        let db = Firestore.firestore()
        if let tournamentID = tournament.id {
            db.collection("tournaments").document(tournamentID).delete { error in
                if let error = error {
                    print("Error deleting tournament: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct EditTournamentView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var tournament: Tournament
    var isEditing: Bool
    var onSave: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Title", text: $tournament.title)
                }
                
                Section(header: Text("Date Range")) {
                    DatePicker("Start Date", selection: Binding(
                        get: { tournament.startDate.dateValue() },
                        set: { tournament.startDate = Timestamp(date: $0) }
                    ), displayedComponents: .date)
                    
                    DatePicker("End Date", selection: Binding(
                        get: { tournament.endDate.dateValue() },
                        set: { tournament.endDate = Timestamp(date: $0) }
                    ), displayedComponents: .date)
                }
                
                Section(header: Text("Link")) {
                    TextField("Link", text: $tournament.link)
                }
                
                Button(action: saveTournament) {
                    Text(isEditing ? "Save Changes" : "Add Tournament")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(15)
                }
                
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(15)
                }
            }
            .navigationTitle(isEditing ? "Edit Tournament" : "Add Tournament")
        }
    }
    
    func saveTournament() {
        let db = Firestore.firestore()
        do {
            if isEditing, let tournamentID = tournament.id {
                try db.collection("tournaments").document(tournamentID).setData(from: tournament)
            } else {
                _ = try db.collection("tournaments").addDocument(from: tournament)
            }
            onSave()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving tournament: \(error.localizedDescription)")
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()

#Preview {
    TournamentsView()
}
