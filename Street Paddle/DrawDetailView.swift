import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct DrawDetailView: View {
    var tournamentName: String
    var categoryName: String
    @State private var rounds: [[String]] = []  // Stores player names for each round
    @State private var scoresPerRound: [[String]] = []  // Stores scores for each round
    @State private var currentRound: Int = 0  // Always start from round 1 on load
    @State private var championName: String = ""  // Separate state for champion's name
    @State private var championScore: String = ""  // Separate state for champion's score
    @State private var isAdmin: Bool = false
    @State private var isLoading: Bool = true  // Loading state for fetching data
    @State private var numberOfPlayers: Int = 0  // Store the number of players from tournament setup

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading tournament data...")
            } else {
                Text("\(tournamentName) - \(categoryName)")
                    .font(.title)
                    .padding()

                if currentRound == rounds.count {  // Show Champion view when currentRound exceeds the number of rounds
                    championView()
                } else {
                    roundView()  // Show rounds
                }

                navigationButtons()
            }
        }
        .padding()
        .onAppear {
            loadDraw()  // Load draw data
            checkIfAdmin()
        }
    }

    // MARK: - Helper Methods

    private func loadDraw() {
        let db = Firestore.firestore()
        let tournamentRef = db.collection("tournaments").document(tournamentName)
        let drawsRef = tournamentRef.collection("draws").document(categoryName)
        let roundsRef = drawsRef.collection("rounds")

        tournamentRef.getDocument { document, error in
            if let error = error {
                print("Error fetching tournament details: \(error.localizedDescription)")
                self.isLoading = false
                return
            }

            guard let document = document, document.exists else {
                print("Tournament document does not exist.")
                self.isLoading = false
                return
            }

            self.numberOfPlayers = document.data()?["numberOfPlayers"] as? Int ?? 8
            initializeEmptyDraw()

            roundsRef.order(by: "__name__").getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching rounds: \(error.localizedDescription)")
                    self.isLoading = false
                    return
                }

                guard let snapshot = snapshot else {
                    print("No rounds found.")
                    self.isLoading = false
                    return
                }

                var fetchedRounds: [[String]] = []
                var fetchedScores: [[String]] = []
                var championData: (name: String, score: String)? = nil
                var finalRoundData: (names: [String], scores: [String])? = nil

                for document in snapshot.documents {
                    let docID = document.documentID
                    if docID == "champion" {
                        let data = document.data()
                        let name = data["championName"] as? String ?? ""
                        let score = data["championScore"] as? String ?? ""
                        championData = (name, score)
                    } else if docID == "final" {
                        // Capture the final round data
                        let data = document.data()
                        let playerNames = data["playerNames"] as? [String] ?? []
                        let scores = data["scores"] as? [String] ?? []
                        finalRoundData = (playerNames, scores)
                    } else if docID.starts(with: "round_") {
                        let data = document.data()
                        let playerNames = data["playerNames"] as? [String] ?? []
                        let scores = data["scores"] as? [String] ?? []
                        fetchedRounds.append(playerNames)
                        fetchedScores.append(scores)
                    }
                }

                DispatchQueue.main.async {
                    if !fetchedRounds.isEmpty {
                        self.rounds = fetchedRounds
                        self.scoresPerRound = fetchedScores
                    }

                    // Append final round data if present
                    if let finalRound = finalRoundData {
                        self.rounds.append(finalRound.names)
                        self.scoresPerRound.append(finalRound.scores)
                    }

                    // Load champion data
                    if let champion = championData {
                        self.championName = champion.name
                        self.championScore = champion.score
                    }

                    self.currentRound = 0
                    self.isLoading = false
                }
            }
        }
    }

    private func bindingScore(at index: Int) -> Binding<String> {
        return Binding(
            get: {
                if currentRound < scoresPerRound.count && index < scoresPerRound[currentRound].count {
                    return scoresPerRound[currentRound][index]
                }
                return ""
            },
            set: { newValue in
                if currentRound < scoresPerRound.count && index < scoresPerRound[currentRound].count {
                    scoresPerRound[currentRound][index] = newValue
                }
            }
        )
    }

    private func bindingRound(at index: Int) -> Binding<String> {
        return Binding(
            get: {
                if currentRound < rounds.count && index < rounds[currentRound].count {
                    return rounds[currentRound][index]
                }
                return ""
            },
            set: { newValue in
                if currentRound < rounds.count && index < rounds[currentRound].count {
                    rounds[currentRound][index] = newValue
                }
            }
        )
    }

    private func initializeEmptyDraw() {
        if rounds.isEmpty {
            let initialRound = Array(repeating: "", count: numberOfPlayers)
            rounds.append(initialRound)
            scoresPerRound.append(Array(repeating: "", count: numberOfPlayers))
        }
    }

    private func numberOfMatchupsInCurrentRound() -> Int {
        return rounds.isEmpty ? 0 : rounds[currentRound].count / 2
    }

    private func isFinalRound() -> Bool {
        return rounds[currentRound].count == 2
    }

    private func declareChampion() {
        // Save the final round data to ensure it's properly stored before declaring the champion
        saveFinalRoundData()

        // Save the champion data (name and score)
        saveChampionData()
    }

    private func saveChampionData() {
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


    private func saveFinalRoundData() {
        guard !rounds.isEmpty, !scoresPerRound.isEmpty else {
            print("Error: Rounds or scores data is empty.")
            return
        }

        guard rounds[currentRound].count == 2 else {
            print("Error: Not the final round (2 players).")
            return
        }

        // Proceed with saving the final round data
        let db = Firestore.firestore()
        let finalRoundData: [String: Any] = [
            "playerNames": rounds[currentRound],
            "scores": scoresPerRound[currentRound]
        ]

        db.collection("tournaments").document(tournamentName)
            .collection("draws").document(categoryName)
            .collection("rounds").document("final").setData(finalRoundData) { error in
                if let error = error {
                    print("Error saving final round data: \(error.localizedDescription)")
                } else {
                    print("Final round data saved successfully.")
                }
            }
    }

    private func saveCurrentRoundData() {
        guard currentRound < rounds.count else { return }

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

    private func goToPreviousRound() {
        if currentRound > 0 {
            currentRound -= 1
        }
    }

    private func advanceToNextRound() {
        if isFinalRound() {
            saveFinalRoundData()  // Save final round data with 2 players only
            currentRound += 1  // Move to the champion view, no need to save champion yet
        } else if currentRound < rounds.count {
            saveCurrentRoundData()  // Save current round data before advancing

            // Ensure the next round has half the players
            let half = rounds[currentRound].count / 2
            
            // Check if the next round already exists (to prevent duplicate rounds)
            if currentRound + 1 >= rounds.count {
                // Create the next round only if it hasn't been created
                let nextRound = Array(repeating: "", count: half)
                rounds.append(nextRound)
                scoresPerRound.append(Array(repeating: "", count: half))
            }

            // Move to the next round
            currentRound += 1
        }
    }

    private func roundTitle() -> String {
        if currentRound >= 0 && currentRound < rounds.count {
            switch rounds[currentRound].count {
            case 2:
                return "Final"
            case 4:
                return "Semifinal"
            default:
                return "Tournament Draw - Round \(currentRound + 1)"
            }
        }
        return "Tournament Draw"
    }

    private func checkIfAdmin() {
        guard let user = Auth.auth().currentUser else { return }
        let allowedEmails = ["carlosmosquera.r@gmail.com", "avillaronga96@gmail.com"]
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists, let email = document.data()?["email"] as? String {
                self.isAdmin = allowedEmails.contains(email)
            }
        }
    }

    // MARK: - Champion View and Round View

    private func championView() -> some View {
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

                Button(action: saveChampionData) {
                    Text("Save Champion")
                        .font(.headline)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
            } else {
                Text("Champion: \(championName)")
                    .font(.title)
                    .padding()

                Text("Score: \(championScore)")
                    .font(.title)
                    .padding()
            }
        }
    }

    private func roundView() -> some View {
        VStack {
            Text(roundTitle())
                .font(.title2)
                .padding()

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<numberOfMatchupsInCurrentRound(), id: \.self) { index in
                        HStack(alignment: .center) {
                            VStack(spacing: 16) {
                                VStack {
                                    if currentRound > 0 || isAdmin {
                                        if isAdmin {
                                            TextField("Score", text: bindingScore(at: index * 2))
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
                                        TextField("Player \(index * 2 + 1)", text: bindingRound(at: index * 2))
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
                                            TextField("Score", text: bindingScore(at: index * 2 + 1))
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
                                        TextField("Player \(index * 2 + 2)", text: bindingRound(at: index * 2 + 1))
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(width: 150)
                                    } else {
                                        Text(rounds[currentRound][index * 2 + 1])
                                            .frame(width: 150)
                                    }
                                }
                            }

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
    }

    private func navigationButtons() -> some View {
        HStack {
            if currentRound > 0 {
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

            if currentRound < rounds.count {  // Control navigation based on currentRound
                Button(action: advanceToNextRound) {
                    Text("Advance to Next Round")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
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
