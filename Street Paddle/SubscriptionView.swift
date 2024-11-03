//
//  SubscriptionView.swift
//  storekit2-youtube-demo-part-2
//
//  Created by Paulo Orquillo on 2/03/23.
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject var storeVM: StoreVM
    @State var isPurchased = false

    var body: some View {
        ZStack {
            // Background styling
            Image("court") // Make sure "court" image exists in your assets
                .resizable()
                .opacity(0.3)
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            VStack {
                Text("STREET PADDLE")
                    .font(.custom("Longhaul", size: 45))
                    .offset(y: -80)

                Group {
                    Section("See you at the pop tennis courts!") {
                        ForEach(storeVM.subscriptions) { product in
                            Button(action: {
                                Task {
                                    await buy(product: product)
                                }
                            }) {
                                VStack {
                                    HStack {
                                        Text(product.displayPrice)
                                        Text(product.displayName)
                                    }
                                }
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(15.0)
                            }
                            .foregroundColor(.white)
                        }
                    }
                }
                
                // Add the endless tennis game view here
                EndlessTennisGameView()
                    .frame(height: 300) // Adjust the frame as needed
                    .padding(.top, 20)
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