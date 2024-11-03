import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var isUserAuthenticated = false
    @StateObject var storeVM = StoreVM()

    var body: some View {
//        
//        VStack{
//            if let subscriptionGroupStatus = storeVM.subscriptionGroupStatus {
//                         if subscriptionGroupStatus == .expired || subscriptionGroupStatus == .revoked {
//                             Text("Welcome back, give the subscription another try.")
//                             //display products
//                         }
//                     }
//                     if storeVM.purchasedSubscriptions.isEmpty {
//                         SubscriptionView()
//                         
//                     } else {
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
          
//        }
//        .environmentObject(storeVM)
//
//    }

    func checkAuthentication() {
        if Auth.auth().currentUser != nil {
            isUserAuthenticated = true
        } else {
            isUserAuthenticated = false
        }
    }
}
