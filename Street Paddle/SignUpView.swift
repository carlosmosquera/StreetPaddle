import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    @Binding var isUserAuthenticated: Bool
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var showVerificationAlert = false

    var body: some View {
        ZStack {
            Image(.court)
                .resizable()
                .opacity(0.3)
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            VStack {
                Image(.spLogoWhite)
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .padding()
                    .offset(x: 0.0, y: -20.0)

                TextField("name", text: $name)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(5.0)
                    .padding([.leading, .bottom, .trailing], 20)

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

                SecureField("Confirm Password", text: $confirmPassword)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(5.0)
                    .padding([.leading, .bottom, .trailing], 20)

                Button(action: signUp) {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 220, height: 60)
                        .background(Color.green)
                        .cornerRadius(15.0)
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
            .alert(isPresented: $showVerificationAlert) {
                Alert(
                    title: Text("Verification Email Sent"),
                    message: Text("Please check your email to verify your account."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    func signUp() {
        guard !name.isEmpty else {
            errorMessage = "Name cannot be empty"
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        let lowercasedEmail = email.lowercased()
        let lowercasedName = name.lowercased()

        Auth.auth().createUser(withEmail: lowercasedEmail, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                guard let user = result?.user else { return }
                
                user.sendEmailVerification { error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                    } else {
                        // Save user data to Firestore
                        let username = lowercasedEmail.components(separatedBy: "@").first ?? ""
                        let db = Firestore.firestore()
                        db.collection("users").document(user.uid).setData([
                            "id": user.uid,
                            "name": lowercasedName,
                            "username": username,
                            "email": lowercasedEmail
                        ]) { error in
                            if let error = error {
                                errorMessage = error.localizedDescription
                            } else {
                                // Notify user to check email
                                showVerificationAlert = true
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SignUpView(isUserAuthenticated: .constant(true))
}
