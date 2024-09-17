import SwiftUI
import FirebaseFirestore

struct TournamentSetupView: View {
    @State private var selectedNumberOfPlayers: Int = 4
    @State private var tournamentName: String = ""
    @State private var categories: [String] = []
    @State private var newCategory: String = ""
    @State private var showConfirmation: Bool = false
    @State private var startDate: Date = Date() // Initial date
    @State private var endDate: Date = Date() // End date

    var body: some View {
        VStack {
            Text("Tournament Setup")
                .font(.headline)
                .padding()

            TextField("Enter Tournament Name", text: $tournamentName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Picker("Select Number of Players", selection: $selectedNumberOfPlayers) {
                ForEach([4, 8, 16, 32, 64], id: \.self) { number in
                    Text("\(number)").tag(number)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            VStack {
                TextField("Add Category", text: $newCategory)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button(action: addCategory) {
                    Text("Add Category")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }

            List(categories, id: \.self) { category in
                Text(category)
            }
            .padding(.top, 10)

            // Date Pickers
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                .padding()
            DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                .padding()

            Button(action: saveTournament) {
                Text("Save Tournament")
                    .font(.headline)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
            .disabled(tournamentName.isEmpty || categories.isEmpty)
            .alert(isPresented: $showConfirmation) {
                Alert(title: Text("Tournament Created"), message: Text("Your tournament has been successfully created."), dismissButton: .default(Text("OK")))
            }
        }
        .padding()
    }

    private func addCategory() {
        if !newCategory.isEmpty {
            categories.append(newCategory)
            newCategory = ""
        }
    }

    private func saveTournament() {
        let db = Firestore.firestore()
        let tournamentData: [String: Any] = [
            "tournamentName": tournamentName,
            "numberOfPlayers": selectedNumberOfPlayers,
            "categories": categories,
            "startDate": Timestamp(date: startDate), // Save start date
            "endDate": Timestamp(date: endDate)      // Save end date
        ]
        
        db.collection("tournaments").document(tournamentName).setData(tournamentData) { error in
            if let error = error {
                print("Error saving tournament: \(error.localizedDescription)")
            } else {
                showConfirmation = true
                resetForm()
            }
        }
    }

    private func resetForm() {
        tournamentName = ""
        selectedNumberOfPlayers = 4
        categories.removeAll()
        startDate = Date()
        endDate = Date()
    }
}
