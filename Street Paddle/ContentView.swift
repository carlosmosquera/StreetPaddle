import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var isUserAuthenticated = false

    var body: some View {
        Group {
            if isUserAuthenticated {
                MainView(isUserAuthenticated: $isUserAuthenticated)
            } else {
                LoginView(isUserAuthenticated: $isUserAuthenticated)
            }
        }
        .onAppear {
            checkAuthentication()
        }
    }

    func checkAuthentication() {
        if Auth.auth().currentUser != nil {
            isUserAuthenticated = true
        } else {
            isUserAuthenticated = false
        }
    }
}
