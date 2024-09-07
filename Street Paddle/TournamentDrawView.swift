import SwiftUI
import FirebaseFirestore

struct TournamentDrawView: View {
    @State private var tournaments: [String] = []
    @State private var selectedTournamentName: String? = nil
    @State private var selectedCategory: String? = nil

    var body: some View {
        NavigationView {
            VStack {
                if let selectedTournamentName = selectedTournamentName {
                    if let selectedCategory = selectedCategory {
                        DrawDetailView(tournamentName: selectedTournamentName, categoryName: selectedCategory)
                    } else {
                        CategorySelectionView(tournamentName: selectedTournamentName)
                    }
                } else {
                    List(tournaments, id: \.self) { tournament in
                        Button(action: {
                            self.selectedTournamentName = tournament
                        }) {
                            Text(tournament)
                        }
                    }
                    .onAppear {
                        loadTournaments()
                    }
                }
            }
        }
    }

    private func loadTournaments() {
        let db = Firestore.firestore()
        db.collection("tournaments").getDocuments { snapshot, error in
            if let snapshot = snapshot {
                self.tournaments = snapshot.documents.map { $0.documentID }
            } else {
                print("Error loading tournaments: \(error?.localizedDescription ?? "")")
            }
        }
    }
}

struct CategorySelectionView: View {
    var tournamentName: String

    @State private var categories: [String] = []

    var body: some View {
        List(categories, id: \.self) { category in
            NavigationLink(destination: DrawDetailView(tournamentName: tournamentName, categoryName: category)) {
                Text(category)
            }
        }
        .onAppear {
            loadCategories()
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
