//
//  Structures.swift
//  Street Paddle
//
//  Created by Carlos Mosquera on 8/21/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PublicMessage: Identifiable, Codable {
    @DocumentID var id: String? // Auto-generated by Firestore
    var senderId: String // User ID of the sender
    var senderName: String // Name of the sender
    var senderUsername: String // Username of the sender
    var content: String // Message content
    var timestamp: Timestamp // Time when the message was posted

    // You can add any other relevant fields here
}

struct GroupChat: Identifiable, Codable {
    @DocumentID var id: String?
    var members: [String]
    var directChatName: String? // Direct chat name (for 2 users)
    var groupChatName: String? // Group chat name (for 3 or more users)
    var latestMessage: String?
    var latestMessageTimestamp: Timestamp?
    var creatorUsername: String?
    var recipientUsernames: [String]?
    var creatorUserID: String?
    var unreadCount: Int?

}


struct GroupMessage: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    var timestamp: Timestamp
    var senderName: String?

    static func == (lhs: GroupMessage, rhs: GroupMessage) -> Bool {
        return lhs.id == rhs.id
    }
}

struct Availability: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var userName: String
    var username: String
    var duration: String
    var level: String
    var gameType: String
    var timestamp: Timestamp
    
    func toDictionary() -> [String: Any] {
        return [
            "userId": userId,
            "userName": userName,
            "username": username,
            "duration": duration,
            "level": level,
            "gameType": gameType,
            "timestamp": timestamp
        ]
    }
}

struct User: Hashable {
    let name: String
    let username: String
}


