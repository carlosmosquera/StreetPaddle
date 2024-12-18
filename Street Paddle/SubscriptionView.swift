import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject var storeVM: StoreVM
    @State var isPurchased = false

    // Customizable horizontal offset
    @State private var xOffset: CGFloat = -20 // Adjust this value to move content left or right

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Image("court")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.3)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        Text("STREET PADDLE")
                            .font(.custom("Longhaul", size: geometry.size.width * 0.1))
                            .multilineTextAlignment(.center)

                        // Subscription Message
                        Text("Unlock exclusive features with a yearly subscription!")
                            .font(.system(size: 14, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, geometry.size.width * 0.05)

                        // Subscription Details
                        VStack(spacing: 10) {
                            Text("Subscription Details:")
                                .font(.system(size: 14, weight: .bold))
                            Text("14-day free trial, then $12.99/year.")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }

                        // Benefits List
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Benefits include:")
                                .font(.system(size: 14, weight: .bold))
                            Text("• Full access to all content and updates.")
                            Text("• Tournament draws and scheduling.")
                            Text("• Access to new features and enhancements.")
                            Text("• Check-in at the courts. All Ad-free.")
                        }
                        .font(.system(size: 14))
                        .padding(.horizontal, geometry.size.width * 0.05)

                        // CTA Message
                        Text("A yearly subscription is required to access the content of the app.")
                            .font(.system(size: 14, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, geometry.size.width * 0.05)

                        // Subscription Button
                        Button(action: {
                            Task {
                                if let product = storeVM.subscriptions.first {
                                    await buy(product: product)
                                }
                            }
                        }) {
                            VStack(spacing: 2) {
                                Text("14-day free trial")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                
                                Text("$12.99 Yearly")
                                    .bold()
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                            .frame(width: geometry.size.width * 0.7, height: 60)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        // Privacy and Restore Section
                        VStack(spacing: 10) {
                            HStack(spacing: 5) {
                                Link("Privacy Policy", destination: URL(string: "https://www.termsfeed.com/live/f0c1ded7-480c-46b6-83b1-5d20fec86a53")!)
                                Text("|")
                                    .foregroundColor(.gray)
                                Link("Terms & Conditions", destination: URL(string: "https://streetpaddle.co/terms-conditions/")!)
                            }
                            .foregroundColor(.blue)
                            .font(.system(size: 12))

                            Button("Restore Purchases") {
                                Task { await storeVM.restorePurchases() }
                            }
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                        }

                        // Endless Tennis Game View
                        EndlessTennisGameView()
                            .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.3)
                            .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.bottom, 40)
                    .offset(x: xOffset) // Apply the horizontal offset
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    func buy(product: Product) async {
        do {
            if try await storeVM.purchase(product) != nil {
                isPurchased = true
            }
        } catch {
            print("Purchase failed")
        }
    }
}
// Simple endless tennis game view
struct EndlessTennisGameView: View {
    @State private var ballPosition = CGPoint(x: 150, y: 150)
    @State private var ballVelocity = CGSize(width: 4, height: 4)
    @State private var paddlePosition = CGFloat(150)
    let paddleWidth: CGFloat = 100
    let paddleHeight: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Ball
                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .position(ballPosition)

                // Paddle
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: paddleWidth, height: paddleHeight)
                    .position(x: paddlePosition, y: geometry.size.height - 30)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                paddlePosition = gesture.location.x
                            }
                    )
            }
            .background(Color.green.opacity(0.2))
            .onAppear {
                startGameLoop(geometry: geometry)
            }
        }
    }

    func startGameLoop(geometry: GeometryProxy) {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            ballPosition.x += ballVelocity.width
            ballPosition.y += ballVelocity.height

            // Ball collision with walls
            if ballPosition.x <= 0 || ballPosition.x >= geometry.size.width {
                ballVelocity.width *= -1
            }
            if ballPosition.y <= 0 {
                ballVelocity.height *= -1
            }

            // Ball collision with paddle
            if ballPosition.y >= geometry.size.height - 30 &&
                ballPosition.x > paddlePosition - paddleWidth / 2 &&
                ballPosition.x < paddlePosition + paddleWidth / 2 {
                ballVelocity.height *= -1
            }

            // Reset if ball goes out of bounds
            if ballPosition.y > geometry.size.height {
                ballPosition = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView().environmentObject(StoreVM())
    }
}
