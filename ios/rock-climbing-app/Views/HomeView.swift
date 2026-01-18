//
//  HomeView.swift
//  RockClimber
//
//  Created on 2026-01-17
//

import SwiftUI

struct HomeView: View {
    @AppStorage("currentUserId") private var currentUserId = "demo-user"
    @State private var todayClimbs = 0
    @State private var todaySends = 0
    @State private var todayElapsedSeconds = 0
    @State private var isLoadingSession = false
    @State private var hasLoadedSession = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // welcome header
                VStack(alignment: .leading, spacing: 5) {
                    Text("Welcome back!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Ready to crush some routes?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // quick actions
                VStack(alignment: .leading, spacing: 15) {
                    Text("Quick Actions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack(spacing: 15) {
                        QuickActionCard(
                            title: "Scan Route",
                            icon: "camera.fill",
                            color: .blue,
                            destination: AnyView(ScanRouteHubView())
                        )
                        
                        QuickActionCard(
                            title: "Progress",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .orange,
                            destination: AnyView(ProgressDashboardView())
                        )
                    }
                    .padding(.horizontal)
                }
                
                // today's stats
                VStack(alignment: .leading, spacing: 15) {
                    Text("Today's Session")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack(spacing: 15) {
                        TodayStatCard(title: "Climbs", value: "\(todayClimbs)", icon: "figure.climbing")
                        TodayStatCard(title: "Time", value: timeString(from: todayElapsedSeconds), icon: "clock.fill")
                        TodayStatCard(title: "Sends", value: "\(todaySends)", icon: "checkmark.circle.fill")
                    }
                    .padding(.horizontal)
                }
                
                // recent activity
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Recent Activity")
                            .font(.headline)
                        
                        Spacer()
                        
                        NavigationLink(destination: ProgressDashboardView()) {
                            Text("View All")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    ForEach(0..<3) { index in
                        RecentActivityCard(
                            route: "V\(4 - index)",
                            gym: "Local Climbing Gym",
                            date: Date().addingTimeInterval(-Double(index) * 86400),
                            completed: index != 1
                        )
                        .padding(.horizontal)
                    }
                }
                
                // training goals
                VStack(alignment: .leading, spacing: 15) {
                    Text("This Week's Goals")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    GoalProgressCard(
                        title: "Complete 20 climbs",
                        current: 14,
                        target: 20
                    )
                    .padding(.horizontal)
                    
                    GoalProgressCard(
                        title: "Send a V5",
                        current: 3,
                        target: 5,
                        unit: "attempts"
                    )
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 20)
            }
            .padding(.top)
        }
        .navigationTitle("RockClimber")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            if !hasLoadedSession {
                hasLoadedSession = true
                await loadTodaySession()
            }
        }
    }

    @MainActor
    private func loadTodaySession() async {
        guard !isLoadingSession else { return }
        isLoadingSession = true
        defer { isLoadingSession = false }
        
        do {
            let session = try await ReadSessionRequest.startTodaySession(userId: currentUserId)
            applySession(session)
        } catch {
            // keep placeholder values if the backend is unavailable
        }
    }
    
    private func applySession(_ session: TodaySessionResponseBody) {
        todayClimbs = session.climbs
        todaySends = session.sends
        todayElapsedSeconds = session.elapsedSeconds
    }
    
    private func timeString(from totalSeconds: Int) -> String {
        guard totalSeconds > 0 else { return "0m" }
        let totalMinutes = totalSeconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(color)
            .cornerRadius(15)
        }
    }
}

struct TodayStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct RecentActivityCard: View {
    let route: String
    let gym: String
    let date: Date
    let completed: Bool
    
    var body: some View {
        HStack {
            Image(systemName: completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(completed ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(route)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(gym) • \(date, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            NavigationLink(destination: AnalysisFeedbackView()) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct GoalProgressCard: View {
    let title: String
    let current: Int
    let target: Int
    var unit: String = "climbs"
    
    var progress: Double {
        Double(current) / Double(target)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(current)/\(target) \(unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 10)
                        .cornerRadius(5)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progress, height: 10)
                        .cornerRadius(5)
                }
            }
            .frame(height: 10)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    NavigationView {
        HomeView()
    }
}
