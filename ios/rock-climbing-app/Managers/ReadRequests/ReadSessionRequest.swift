//
//  ReadSessionRequest.swift
//  RockClimber
//
//  Created on 2026-01-17
//

import Foundation

class ReadSessionRequest {
    struct ClimbEventBody: Encodable {
        let status: ClimbStatus
        let attempts: Int
        let durationSeconds: Int
    }
    
    static func startTodaySession(userId: String) async throws -> TodaySessionResponseBody {
        return try await APIClient.shared.request(
            path: "/api/users/\(userId)/sessions/today/start",
            method: .post
        )
    }
    
    static func endTodaySession(userId: String) async throws -> TodaySessionResponseBody {
        return try await APIClient.shared.request(
            path: "/api/users/\(userId)/sessions/today/end",
            method: .post
        )
    }
    
    static func getTodaySession(userId: String) async throws -> TodaySessionResponseBody {
        return try await APIClient.shared.request(
            path: "/api/users/\(userId)/sessions/today",
            method: .get
        )
    }
    
    static func addClimbEvent(userId: String, body: ClimbEventBody) async throws -> TodaySessionResponseBody {
        return try await APIClient.shared.request(
            path: "/api/users/\(userId)/sessions/today/climbs",
            method: .post,
            body: body
        )
    }
}
