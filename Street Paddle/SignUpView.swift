import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    @Binding var isUserAuthenticated: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""

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

                TextField("Email", text: $email)
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
        }
    }

    func signUp() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                guard let user = result?.user else { return }
                let username = email.components(separatedBy: "@").first ?? ""
                let db = Firestore.firestore()
                db.collection("users").document(user.uid).setData([
                    "username": username,
                    "email": email
                ]) { error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                    } else {
                        isUserAuthenticated = true
                    }
                }
            }
        }
    }
}

#Preview {
    SignUpView(isUserAuthenticated: .constant(true))
}
