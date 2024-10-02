//
//  Street_PaddleApp.swift
//  Street Paddle
//
//  Created by Carlos Mosquera on 7/31/24.
//

import SwiftUI
import Firebase
import UserNotifications

@main
struct Street_PaddleApp: App {
    @StateObject private var notificationManager = NotificationManager() // Create an instance of NotificationManager

    
    init() {
        FirebaseApp.configure()
        
        // Request permission to show badges and notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationManager) // Provide the notification manager to the environment

        }
    }
}
