import SwiftUI
import FirebaseFirestore

struct AdminTournamentsView: View {
    @State private var title = ""
    @State private var date = Date()
    @State private var description = ""
    @State private var tournaments = [Tournament]()

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Add Tournament")) {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Description", text: $description)
                }
                Button(action: addTournament) {
                    Text("Add Tournament")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .padding()

            List(tournaments) { tournament in
                NavigationLink(destination: TournamentDetailView(tournament: tournament)) {
                    VStack(alignment: .leading) {
                        Text(tournament.title)
                            .font(.headline)
                        Text(tournament.date, style: .date)
                            .font(.subheadline)
                    }
                }
            }
        }
        .onAppear(perform: fetchTournaments)
        .navigationTitle("Manage Tournaments")
    }

    func fetchTournaments() {
        let db = Firestore.firestore()
        db.collection("tournaments")
            .order(by: "date", descending: false)
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
        let db = Firestore.firestore()
        let newTournament = Tournament(title: title, date: date, description: description)
        do {
            try db.collection("tournaments").addDocument(from: newTournament)
            title = ""
            date = Date()
            description = ""
        } catch {
            print("Error adding tournament: \(error.localizedDescription)")
        }
    }
}


struct TournamentDetailView: View {
    var tournament: Tournament

    var body: some View {
        VStack {
            Text(tournament.title)
                .font(.largeTitle)
                .padding()
            Text(tournament.date, style: .date)
                .font(.headline)
                .padding()
            Text(tournament.description)
                .font(.body)
                .padding()
        }
        .navigationTitle("Tournament Details")
    }
}

#Preview {
    TournamentDetailView(tournament: Tournament(title: "Sample Tournament", date: Date(), description: "This is a sample tournament description."))
}

#Preview {
    AdminTournamentsView()
}
