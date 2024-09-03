import SwiftUI

struct TournamentDrawView: View {
    @State private var tournaments: [String: [String: Any]] = [:] // Dictionary of tournaments
    @State private var selectedTournamentName: String? = nil
    @State private var selectedCategory: String? = nil

    var body: some View {
        NavigationView {
            VStack {
                if let selectedTournamentName = selectedTournamentName {
                    if let selectedCategory = selectedCategory {
                        DrawDetailView(tournamentName: selectedTournamentName, categoryName: selectedCategory)
                    } else {
                        CategorySelectionView(tournamentName: selectedTournamentName, categories: tournaments[selectedTournamentName]?["categories"] as? [String] ?? [])
                    }
                } else {
                    List {
                        ForEach(Array(tournaments.keys), id: \.self) { tournament in
                            Button(action: {
                                self.selectedTournamentName = tournament
                            }) {
                                Text(tournament)
                                    .font(.headline)
                                    .padding()
                            }
                        }
                    }
                    .navigationTitle("Select Tournament")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                if let url = URL(string: "https://streetpaddle.co/tournaments/") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("StreetPaddle.com")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
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
        // Load the list of tournaments from storage
        if let storedTournaments = UserDefaults.standard.dictionary(forKey: "tournaments") as? [String: [String: Any]] {
            tournaments = storedTournaments
        } else {
            tournaments = [:]
        }
    }
}

struct CategorySelectionView: View {
    var tournamentName: String
    var categories: [String]

    var body: some View {
        List {
            ForEach(categories, id: \.self) { category in
                NavigationLink(destination: DrawDetailView(tournamentName: tournamentName, categoryName: category)) {
                    Text(category)
                        .font(.headline)
                        .padding()
                }
            }
        }
        .navigationTitle("\(tournamentName) Categories")
    }
}

struct DrawDetailView: View {
    var tournamentName: String
    var categoryName: String
    @State private var playerNames: [String]
    @State private var scores: [String]
    @State private var currentRound: Int = 1
    @State private var championName: String = ""

    init(tournamentName: String, categoryName: String) {
        self.tournamentName = tournamentName
        self.categoryName = categoryName

        // Safely cast the retrieved value to a dictionary with expected types
        if let tournaments = UserDefaults.standard.dictionary(forKey: "tournaments") as? [String: [String: Any]],
           let tournamentDetails = tournaments[tournamentName],
           let numberOfPlayers = tournamentDetails["numberOfPlayers"] as? Int {
            _playerNames = State(initialValue: Array(repeating: "", count: numberOfPlayers))
            _scores = State(initialValue: Array(repeating: "", count: numberOfPlayers))
        } else {
            // Fallback to 8 players if no valid data is found
            _playerNames = State(initialValue: Array(repeating: "", count: 8))
            _scores = State(initialValue: Array(repeating: "", count: 8))
        }
    }


    var body: some View {
        VStack {
            Text("\(tournamentName) - \(categoryName)")
                .font(.title)
                .padding()

            Text(roundTitle())
                .font(.title2)
                .padding()

            if roundTitle() != "Champion" {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(0..<playerNames.count / 2, id: \.self) { index in
                            HStack(alignment: .center) {
                                VStack(spacing: 16) {
                                    VStack {
                                        TextField("Score", text: $scores[index * 2])
                                            .font(.caption)
                                            .frame(width: 50)
                                            .multilineTextAlignment(.center)

                                        TextField("Player \(index * 2 + 1)", text: $playerNames[index * 2])
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(width: 150)
                                    }
                                    
                                    VStack {
                                        TextField("Score", text: $scores[index * 2 + 1])
                                            .font(.caption)
                                            .frame(width: 50)
                                            .multilineTextAlignment(.center)

                                        TextField("Player \(index * 2 + 2)", text: $playerNames[index * 2 + 1])
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(width: 150)
                                    }
                                }
                                
                                // Vertical and horizontal connecting lines
                                VStack(spacing: 16) {
                                    LineConnector()
                                        .stroke(lineWidth: 2)
                                        .frame(width: 2, height: 100)
                                        .alignmentGuide(.leading) { _ in 75 }
                                        .offset(x: -40, y: 20) // Lower the vertical line by 10

                                    LineConnectorHorizontal()
                                        .stroke(lineWidth: 2)
                                        .frame(width: 70, height: 2)
                                        .alignmentGuide(.leading) { d in d[.trailing] }
                                        .offset(x: -5, y: -50) // Position horizontal line to the right by 30 and in the middle of the vertical line
                                }
                                .padding(.leading, 10)
                            }
                        }
                    }
                }
            } else {
                VStack {
                    TextField("Champion", text: $championName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.title)
                        .padding()

                    Button(action: saveChampion) {
                        Text("Save Champion")
                            .font(.headline)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 20)
                }
            }

            HStack {
                if currentRound > 1 {
                    Button(action: goToPreviousRound) {
                        Text("Previous Round")
                            .font(.headline)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 20)
                }

                Spacer()

                if playerNames.count > 2 {
                    Button(action: advanceToNextRound) {
                        Text("Advance to Next Round")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 20)
                } else if playerNames.count == 2 {
                    Button(action: showChampion) {
                        Text("Show Champion")
                            .font(.headline)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .padding()
    }

    private func advanceToNextRound() {
        let half = playerNames.count / 2
        playerNames = Array(repeating: "", count: half)
        scores = Array(repeating: "", count: half)
        currentRound += 1
    }

    private func goToPreviousRound() {
        let double = playerNames.count * 2
        playerNames = Array(repeating: "", count: double)
        scores = Array(repeating: "", count: double)
        currentRound -= 1
    }

    private func showChampion() {
        playerNames = Array(repeating: "", count: 1)
        scores = Array(repeating: "", count: 1)
        currentRound += 1
    }

    private func saveChampion() {
        // Save the champion's name (for example, to UserDefaults or Firestore)
        UserDefaults.standard.set(championName, forKey: "\(tournamentName)_\(categoryName)_champion")
    }

    private func roundTitle() -> String {
        switch playerNames.count {
        case 2:
            return "Final"
        case 4:
            return "Semifinal"
        case 1:
            return "Champion"
        default:
            return "Tournament Draw - Round \(currentRound)"
        }
    }
}

struct LineConnector: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

struct LineConnectorHorizontal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

#Preview {
    TournamentSetupView()
}
