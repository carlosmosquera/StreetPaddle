import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @Binding var isUserAuthenticated: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showSignUp = false

    var body: some View {
        ZStack {
            Image(.court)
                .resizable()
                .opacity(0.3)
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            VStack {
                Text("STREET PADDLE")
                    .frame(height: 0.0)
                    .offset(x: 0.0, y: -80.0)
                    .font(.custom("Longhaul", size: 45))

                TextField("email", text: $email)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(5.0)
                    .padding([.leading, .bottom, .trailing], 20)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(5.0)
                    .padding([.leading, .bottom, .trailing], 20)

                Button(action: login) {
                    Text("Log In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 220, height: 60)
                        .background(Color.blue)
                        .cornerRadius(15.0)
                }

                Text("By logging in, you indicate that you have read and agree to the Terms of Conditions and Privacy Policy.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                Button(action: {
                    showSignUp.toggle()
                }) {
                    Text("Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                        .padding()
                }
                .sheet(isPresented: $showSignUp) {
                    SignUpView(isUserAuthenticated: $isUserAuthenticated)
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
        }
    }

    func login() {
        let lowercasedEmail = email.lowercased()

        Auth.auth().signIn(withEmail: lowercasedEmail, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                guard let user = result?.user else { return }
                if user.isEmailVerified {
                    isUserAuthenticated = true
                } else {
                    errorMessage = "Please verify your email before logging in."
                }
            }
        }
    }
}

#Preview {
    LoginView(isUserAuthenticated: .constant(true))
}
