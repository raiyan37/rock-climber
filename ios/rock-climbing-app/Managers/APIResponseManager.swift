//
//  APIResponseManager.swift
//  RockClimber
//
//  Created on 2026-01-17
//

import SwiftUI

// api response structs for each view - only contains info specific to that view

// MARK: - Enums

enum ClimbingGrade: String, Codable, CaseIterable {
    case v0 = "V0"
    case v1 = "V1"
    case v2 = "V2"
    case v3 = "V3"
    case v4 = "V4"
    case v5 = "V5"
    case v6 = "V6"
    case v7 = "V7"
    case v8 = "V8"
    case v9 = "V9"
    case v10 = "V10"
    case v11 = "V11"
    case v12 = "V12"
    case v13 = "V13"
    case v14 = "V14"
    case v15 = "V15"
    case v16 = "V16"
    case v17 = "V17"
    
    var difficulty: Int {
        switch self {
        case .v0: return 0
        case .v1: return 1
        case .v2: return 2
        case .v3: return 3
        case .v4: return 4
        case .v5: return 5
        case .v6: return 6
        case .v7: return 7
        case .v8: return 8
        case .v9: return 9
        case .v10: return 10
        case .v11: return 11
        case .v12: return 12
        case .v13: return 13
        case .v14: return 14
        case .v15: return 15
        case .v16: return 16
        case .v17: return 17
        }
    }
    
    var color: Color {
        switch difficulty {
        case 0...2: return .green
        case 3...5: return .blue
        case 6...8: return .orange
        case 9...11: return .red
        default: return .purple
        }
    }
}

enum RouteType: String, Codable {
    case boulder = "BOULDER"
    case sport = "SPORT"
    case toprope = "TOPROPE"
    case trad = "TRAD"
    
    var displayName: String {
        switch self {
        case .boulder: return "Boulder"
        case .sport: return "Sport"
        case .toprope: return "Top Rope"
        case .trad: return "Trad"
        }
    }
}

enum ClimbStatus: String, Codable {
    case attempted = "ATTEMPTED"
    case completed = "COMPLETED"
    case project = "PROJECT"
    case flash = "FLASH"
    case onsight = "ONSIGHT"
    
    var displayName: String {
        switch self {
        case .attempted: return "Attempted"
        case .completed: return "Completed"
        case .project: return "Project"
        case .flash: return "Flash"
        case .onsight: return "Onsight"
        }
    }
    
    var color: Color {
        switch self {
        case .attempted: return .orange
        case .completed: return .green
        case .project: return .blue
        case .flash: return .yellow
        case .onsight: return .purple
        }
    }
}

enum AnalysisStatus: String, Codable {
    case pending = "PENDING"
    case processing = "PROCESSING"
    case completed = "COMPLETED"
    case failed = "FAILED"
}

enum ClimbingStyle: String, Codable {
    case technical = "TECHNICAL"
    case power = "POWER"
    case endurance = "ENDURANCE"
    case dynamic = "DYNAMIC"
    
    var displayName: String {
        switch self {
        case .technical: return "Technical"
        case .power: return "Power"
        case .endurance: return "Endurance"
        case .dynamic: return "Dynamic"
        }
    }
}

// MARK: - Response Bodies

// response for HomeView/FeedView
// get user's feed with recent posts
struct FeedResponseBody: Codable {
    var posts: [Post]
    
    struct Post: Identifiable, Codable {
        var id: String
        var user: User
        var climb: Climb
        var caption: String?
        var videoURL: String?
        var thumbnailURL: String?
        var likes: Int
        var comments: Int
        var isLiked: Bool
        var createdAt: Date
    }
    
    struct User: Codable {
        var id: String
        var firstName: String
        var lastName: String
        var photoURL: String?
    }
    
    struct Climb: Codable {
        var routeName: String
        var grade: ClimbingGrade
        var status: ClimbStatus
        var gymName: String?
    }
}

// response for HomeView
// get today's session stats
struct TodaySessionResponseBody: Codable {
    var climbs: Int
    var sends: Int
    var elapsedSeconds: Int
    var isActive: Bool
}

// response for ProfileView
// get user profile and stats
struct ProfileResponseBody: Codable {
    var user: User
    var stats: Stats
    var sendPyramid: [SendPyramidEntry]
    var stylePreferences: [StylePreference]
    var recentActivity: [Activity]
    
    struct User: Codable {
        var id: String
        var firstName: String
        var lastName: String
        var email: String
        var photoURL: String?
        var memberSince: Date
        var maxGrade: ClimbingGrade
    }
    
    struct Stats: Codable {
        var totalClimbs: Int
        var successRate: Double
        var currentGrade: ClimbingGrade
        var totalSessions: Int
        var followers: Int
        var following: Int
    }
    
    struct SendPyramidEntry: Identifiable, Codable {
        var id: String { grade.rawValue }
        var grade: ClimbingGrade
        var count: Int
    }
    
    struct StylePreference: Identifiable, Codable {
        var id: String { style.rawValue }
        var style: ClimbingStyle
        var percentage: Int
    }
    
    struct Activity: Identifiable, Codable {
        var id: String
        var routeName: String
        var grade: ClimbingGrade
        var status: ClimbStatus
        var date: Date
        var gymName: String?
    }
}

// response for ProgressDashboardView
// get user progress data and analytics
struct ProgressResponseBody: Codable {
    var progressData: [ProgressEntry]
    var sessions: [Session]
    var weaknesses: [Weakness]
    var trainingSuggestions: [TrainingSuggestion]
    var injuries: [Injury]
    
    struct ProgressEntry: Identifiable, Codable {
        var id: String
        var date: Date
        var grade: ClimbingGrade
        var count: Int
    }
    
    struct Session: Identifiable, Codable {
        var id: String
        var date: Date
        var duration: Int // in minutes
        var climbCount: Int
        var maxGrade: ClimbingGrade
        var gymName: String?
    }
    
    struct Weakness: Identifiable, Codable {
        var id: String { type }
        var type: String // e.g., "Overhangs", "Crimps", "Slopers"
        var strengthScore: Double // 0.0 to 1.0
    }
    
    struct TrainingSuggestion: Identifiable, Codable {
        var id: String
        var title: String
        var description: String
        var priority: String // "High", "Medium", "Low"
    }
    
    struct Injury: Identifiable, Codable {
        var id: String
        var bodyPart: String
        var status: String
        var reportedDate: Date
        var notes: String?
    }
}

// response for RouteAnalysisView
// get ai analysis of a route from uploaded image
struct RouteAnalysisResponseBody: Codable {
    var routeId: String
    var analysisStatus: AnalysisStatus
    var imageURL: String
    var predictedGrade: ClimbingGrade?
    var holds: [Hold]
    var betaOptions: [BetaOption]
    
    struct Hold: Identifiable, Codable {
        var id: String
        var x: Double // normalized 0-1
        var y: Double // normalized 0-1
        var width: Double
        var height: Double
        var type: String // "jug", "crimp", "sloper", "pinch"
        var confidence: Double
    }
    
    struct BetaOption: Identifiable, Codable {
        var id: String
        var number: Int
        var difficulty: String // "Easy", "Medium", "Hard"
        var description: String
        var routePath: [PathPoint]
    }
    
    struct PathPoint: Codable {
        var x: Double // normalized 0-1
        var y: Double // normalized 0-1
    }
}

// response for ClimbRecordingView / AnalysisFeedbackView
// get analysis of recorded climb video
struct ClimbAnalysisResponseBody: Codable {
    var climbId: String
    var analysisStatus: AnalysisStatus
    var videoURL: String
    var duration: Int // in seconds
    var sections: [Section]
    var techniqueScores: [TechniqueScore]
    var corrections: [Correction]
    var comparisonData: ComparisonData?
    
    struct Section: Identifiable, Codable {
        var id: String
        var name: String // "Start", "Middle", "Crux", "Finish"
        var startTime: Double
        var endTime: Double
        var poseData: [PoseFrame]?
    }
    
    struct PoseFrame: Codable {
        var timestamp: Double
        var joints: [Joint]
    }
    
    struct Joint: Codable {
        var name: String
        var x: Double
        var y: Double
        var confidence: Double
    }
    
    struct TechniqueScore: Identifiable, Codable {
        var id: String { category }
        var category: String // "Hip Position", "Arm Extension", etc.
        var score: Int // 0-100
    }
    
    struct Correction: Identifiable, Codable {
        var id: String
        var title: String
        var description: String
        var severity: String // "positive", "minor", "major"
        var timestamp: Double?
    }
    
    struct ComparisonData: Codable {
        var yourMoves: Int
        var optimalMoves: Int
        var efficiencyScore: Double
        var previousAttempts: [AttemptData]
    }
    
    struct AttemptData: Identifiable, Codable {
        var id: String
        var attemptNumber: Int
        var score: Int
        var date: Date
    }
}

// response for saving a climb
struct SaveClimbResponseBody: Codable {
    var climbId: String
    var message: String
    var videoURL: String?
    var analysisStatus: AnalysisStatus
}

// response for creating/updating a route
struct SaveRouteResponseBody: Codable {
    var routeId: String
    var message: String
    var imageURL: String?
    var analysisStatus: AnalysisStatus
}

// response for user authentication
struct AuthResponseBody: Codable {
    var user: User
    var token: String
    var isNewUser: Bool
    
    struct User: Codable {
        var id: String
        var email: String
        var firstName: String
        var lastName: String
        var photoURL: String?
    }
}
