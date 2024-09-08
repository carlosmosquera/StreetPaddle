import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct DrawDetailView: View {
    var tournamentName: String
    var categoryName: String
    @State private var rounds: [[String]] = []  // Stores player names for each round
    @State private var scoresPerRound: [[String]] = []  // Stores scores for each round
    @State private var currentRound: Int = 0  // Start from round 1
    @State private var championName: String = ""  // Separate state for champion's name
    @State private var championScore: String = ""  // Separate state for champion's score
    @State private var isAdmin: Bool = false
    @State private var isLoading: Bool = true  // Add a loading state to avoid premature access
    @State private var isChampionDeclared: Bool = false  // Track if champion has been declared
    @State private var numberOfPlayers: Int = 0  // Store the number of players from tournament setup

    var body: some View {
        VStack {
            if isLoading {
                // Show loading indicator while data is being fetched
                ProgressView("Loading tournament data...")
            } else {
                Text("\(tournamentName) - \(categoryName)")
                    .font(.title)
                    .padding()

                if isChampionDeclared {
                    // Champion Page with independent textfields for the champion's name and score
                    VStack {
                        Text("Champion")
                            .font(.title2)
                            .padding()

                        if isAdmin {
                            TextField("Champion Name", text: $championName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding()

                            TextField("Champion Score", text: $championScore)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding()
                        } else {
                            Text("Champion: \(championName)")
                                .font(.title)
                                .padding()

                            Text("Score: \(championScore)")
                                .font(.title)
                                .padding()
                        }
                    }
                } else {
                    Text(roundTitle())
                        .font(.title2)
                        .padding()

                    ScrollView {
                        VStack(spacing: 16) {
                            // For round 1 and other rounds, show players with lines and scores
                            ForEach(0..<rounds[currentRound].count / 2, id: \.self) { index in
                                HStack(alignment: .center) {
                                    VStack(spacing: 16) {
                                        VStack {
                                            if currentRound > 0 || isAdmin {
                                                if isAdmin {
                                                    TextField("Score", text: $scoresPerRound[currentRound][index * 2])
                                                        .font(.caption)
                                                        .frame(width: 50)
                                                        .multilineTextAlignment(.center)
                                                } else {
                                                    Text(scoresPerRound[currentRound][index * 2])
                                                        .font(.caption)
                                                        .frame(width: 50)
                                                        .multilineTextAlignment(.center)
                                                }
                                            }

                                            if isAdmin {
                                                TextField("Player \(index * 2 + 1)", text: $rounds[currentRound][index * 2])
                                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                                    .frame(width: 150)
                                            } else {
                                                Text(rounds[currentRound][index * 2])
                                                    .frame(width: 150)
                                            }
                                        }

                                        VStack {
                                            if currentRound > 0 || isAdmin {
                                                if isAdmin {
                                                    TextField("Score", text: $scoresPerRound[currentRound][index * 2 + 1])
                                                        .font(.caption)
                                                        .frame(width: 50)
                                                        .multilineTextAlignment(.center)
                                                } else {
                                                    Text(scoresPerRound[currentRound][index * 2 + 1])
                                                        .font(.caption)
                                                        .frame(width: 50)
                                                        .multilineTextAlignment(.center)
                                                }
                                            }

                                            if isAdmin {
                                                TextField("Player \(index * 2 + 2)", text: $rounds[currentRound][index * 2 + 1])
                                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                                    .frame(width: 150)
                                            } else {
                                                Text(rounds[currentRound][index * 2 + 1])
                                                    .frame(width: 150)
                                            }
                                        }
                                    }

                                    // Vertical and horizontal connecting lines
                                    VStack(spacing: 16) {
                                        LineConnector()
                                            .stroke(lineWidth: 2)
                                            .frame(width: 2, height: 100)
                                            .alignmentGuide(.leading) { _ in 75 }
                                            .offset(x: -40, y: 20)

                                        LineConnectorHorizontal()
                                            .stroke(lineWidth: 2)
                                            .frame(width: 70, height: 2)
                                            .alignmentGuide(.leading) { d in d[.trailing] }
                                            .offset(x: -5, y: -50)
                                    }
                                    .padding(.leading, 10)
                                }
                            }
                        }
                    }
                }

                HStack {
                    if currentRound > 0 || isChampionDeclared {
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

                    if !isChampionDeclared && !isFinalRound() {
                        Button(action: advanceToNextRound) {
                            Text("Advance to Next Round")
                                .font(.headline)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top, 20)
                    } else if isFinalRound() && !isChampionDeclared {
                        Button(action: declareChampion) {
                            Text("Declare Champion")
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
        }
        .padding()
        .onAppear {
            checkIfAdmin()
            loadDraw()
        }
    }

    // Initialize an empty draw with default values if no data exists
    private func initializeEmptyDraw() {
        if rounds.isEmpty {
            rounds = [Array(repeating: "", count: numberOfPlayers)]  // Initialize based on number of players
            scoresPerRound = [Array(repeating: "", count: numberOfPlayers)]
        }
    }

    // Check if current round is the final round
    private func isFinalRound() -> Bool {
        return rounds[currentRound].count == 2
    }

    // Declare the champion and move to the champion page
    private func declareChampion() {
        // Empty the champion fields, they should not carry over from the final round
        championName = ""
        championScore = ""
        isChampionDeclared = true
    }

    // Go to the previous round, including handling the champion page
    private func goToPreviousRound() {
        if isChampionDeclared {
            isChampionDeclared = false  // Unset the champion state
        } else if currentRound > 0 {
            currentRound -= 1  // Go to the previous round
        }
    }

    // Update roundTitle method
    private func roundTitle() -> String {
        if currentRound >= 0 && currentRound < rounds.count {
            switch rounds[currentRound].count {
            case 2:
                return "Final"
            case 4:
                return "Semifinal"
            case 1:
                return "Champion"
            default:
                return "Tournament Draw - Round \(currentRound + 1)"
            }
        }
        return "Tournament Draw"
    }

    private func advanceToNextRound() {
        if rounds.isEmpty {
            initializeEmptyDraw()
        } else {
            saveCurrentRoundData()
            let half = rounds[currentRound].count / 2
            rounds.append(Array(repeating: "", count: half))
            scoresPerRound.append(Array(repeating: "", count: half))
            currentRound += 1
        }
    }

    private func saveChampion() {
        // Save champion details in Firestore
        let db = Firestore.firestore()
        let championData: [String: Any] = [
            "championName": championName,
            "championScore": championScore
        ]
        
        db.collection("tournaments").document(tournamentName)
            .collection("draws").document(categoryName)
            .collection("rounds").document("champion").setData(championData) { error in
            if let error = error {
                print("Error saving champion data: \(error.localizedDescription)")
            } else {
                print("Champion data saved successfully.")
            }
        }
    }

    private func saveCurrentRoundData() {
        let db = Firestore.firestore()
        let roundData: [String: Any] = [
            "playerNames": rounds[currentRound],
            "scores": scoresPerRound[currentRound]
        ]
        
        db.collection("tournaments").document(tournamentName)
            .collection("draws").document(categoryName)
            .collection("rounds").document("round_\(currentRound)").setData(roundData) { error in
            if let error = error {
                print("Error saving round data: \(error.localizedDescription)")
            } else {
                print("Round data saved successfully.")
            }
        }
    }

    private func loadDraw() {
        let db = Firestore.firestore()
        db.collection("tournaments").document(tournamentName)
            .getDocument { document, error in
            if let document = document, document.exists {
                self.numberOfPlayers = document.data()?["numberOfPlayers"] as? Int ?? 8  // Fetch number of players
                initializeEmptyDraw()  // Initialize draw with the correct number of players
                self.isLoading = false
            } else {
                print("Error loading tournament: \(error?.localizedDescription ?? "")")
                self.isLoading = false
            }
        }
    }

    private func checkIfAdmin() {
        guard let user = Auth.auth().currentUser else { return }
        let allowedEmails = ["carlosmosquera.r@gmail.com", "avillaronga96@gmail.com"]
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let document = document, document.exists, let email = document.data()?["email"] as? String {
                self.isAdmin = allowedEmails.contains(email)
            }
        }
    }
}

// Line Connectors (Vertical and Horizontal)
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
