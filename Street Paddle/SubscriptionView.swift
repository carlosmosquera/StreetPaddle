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
                    Section("Enjoy the fun!") {
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


struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView().environmentObject( StoreVM())
    }
}
