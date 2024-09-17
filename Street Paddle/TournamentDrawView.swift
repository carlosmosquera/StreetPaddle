import SwiftUI
import FirebaseFirestore

struct TournamentDrawView: View {
    @State private var tournaments: [(name: String, startDate: Date, endDate: Date)] = []
    @State private var selectedTournamentName: String? = nil
    @State private var selectedCategory: String? = nil

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if let selectedTournamentName = selectedTournamentName {
                    if let selectedCategory = selectedCategory {
                        DrawDetailView(tournamentName: selectedTournamentName, categoryName: selectedCategory)
                    } else {
                        CategorySelectionView(tournamentName: selectedTournamentName)
                    }
                } else {
                    List(tournaments, id: \.name) { tournament in
                        VStack(alignment: .leading) {
                            Text(tournament.name)
                                .font(.headline)
                            Text("Start Date: \(tournament.startDate, formatter: dateFormatter)")
                            Text("End Date: \(tournament.endDate, formatter: dateFormatter)")
                        }
                        .contentShape(Rectangle()) // Makes the entire cell tappable
                        .onTapGesture {
                            self.selectedTournamentName = tournament.name
                        }
                    }
                    .onAppear {
                        loadTournaments()
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func loadTournaments() {
        let db = Firestore.firestore()
        db.collection("tournaments").getDocuments { snapshot, error in
            if let snapshot = snapshot {
                self.tournaments = snapshot.documents.compactMap { document in
                    let data = document.data()
                    let name = document.documentID
                    let startDate = (data["startDate"] as? Timestamp)?.dateValue() ?? Date()
                    let endDate = (data["endDate"] as? Timestamp)?.dateValue() ?? Date()
                    return (name, startDate, endDate)
                }
            } else {
                print("Error loading tournaments: \(error?.localizedDescription ?? "")")
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

struct CategorySelectionView: View {
    var tournamentName: String

    @State private var categories: [String] = []

    var body: some View {
        GeometryReader { geometry in
            List(categories, id: \.self) { category in
                NavigationLink(destination: DrawDetailView(tournamentName: tournamentName, categoryName: category)) {
                    Text(category)
                }
            }
            .onAppear {
                loadCategories()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func loadCategories() {
        let db = Firestore.firestore()
        db.collection("tournaments").document(tournamentName).getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                self.categories = data["categories"] as? [String] ?? []
            }
        }
    }
}
