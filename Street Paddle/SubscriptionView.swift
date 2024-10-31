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
    
    @State private var email = ""
    @State private var password = ""

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

         
                Group {
                    Section("Enjoy the fun!") {
                        ForEach(storeVM.subscriptions) { product in
                            Button(action: {
                                Task {
                                    await buy(product: product)
                                }
                            }
                            )
                            {
                                VStack{
                                    
                        
                                    
                                    HStack {
                                        Text(product.displayPrice)
                                        Text(product.displayName)
                                    }
                                }.padding()
                            }
                            .foregroundColor(Color.white)
//                            .padding()
                            .background(Color.blue)
                            .cornerRadius(15.0)
                            
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
            print("purchase failed")
        }
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView().environmentObject( StoreVM())
    }
}
