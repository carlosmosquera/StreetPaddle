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
//                Image(.spLogoBlack)
//                    .ignoresSafeArea()
//                    .padding()
//                    .offset(x: 0, y: -60)
                
                Text("STREET PADDLE")
                    .frame(height: 0.0)
                    .offset(x: 0.0, y: -80.0)
                    .font(.custom("Longhaul", size: 45))

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

                Button(action: login) {
                    Text("Log In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 220, height: 60)
                        .background(Color.blue)
                        .cornerRadius(15.0)
                }
                
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
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                isUserAuthenticated = true
            }
        }
    }
}

#Preview {
    LoginView(isUserAuthenticated: .constant(true))
}
