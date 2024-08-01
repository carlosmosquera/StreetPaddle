//
//  Street_PaddleApp.swift
//  Street Paddle
//
//  Created by Carlos Mosquera on 7/31/24.
//

import SwiftUI
import Firebase

@main
struct Street_PaddleApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
