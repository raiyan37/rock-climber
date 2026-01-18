//
//  ClimbRecordingView.swift
//  RockClimber
//
//  Created on 2026-01-17
//

import SwiftUI

struct ClimbRecordingView: View {
    @State private var isRecording = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var attemptCount = 1
    @State private var showPoseOverlay = true
    @State private var timer: Timer?
    @AppStorage("currentUserId") private var currentUserId = "demo-user"
    
    var body: some View {
        ZStack {
            // video preview placeholder
            Color.black
                .ignoresSafeArea()
            
            // pose skeleton overlay (optional)
            if showPoseOverlay && isRecording {
                PoseSkeletonOverlay()
            }
            
            VStack {
                // top info bar
                HStack {
                    // attempt counter
                    HStack(spacing: 5) {
                        Image(systemName: "repeat")
                        Text("Attempt \(attemptCount)")
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // timer
                    Text(timeString(from: elapsedTime))
                        .font(.system(.title2, design: .monospaced))
                        .padding(10)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    // pose overlay toggle
                    Button(action: {
                        showPoseOverlay.toggle()
                    }) {
                        Image(systemName: showPoseOverlay ? "figure.walk" : "figure.walk.circle")
                            .font(.title2)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                
                Spacer()
                
                // recording status indicator
                if isRecording {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        
                        Text("Recording")
                            .font(.headline)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
                }
                
                // bottom controls
                HStack(spacing: 40) {
                    // restart attempt button
                    Button(action: {
                        restartAttempt()
                    }) {
                        VStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title)
                            Text("Restart")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.white)
                    .disabled(!isRecording)
                    .opacity(!isRecording ? 0.5 : 1)
                    
                    // record/stop button
                    Button(action: {
                        toggleRecording()
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            
                            if isRecording {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.red)
                                    .frame(width: 35, height: 35)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 70, height: 70)
                            }
                        }
                    }
                    
                    // complete button
                    Button(action: {
                        completeClimb()
                    }) {
                        VStack {
                            Image(systemName: "checkmark.circle")
                                .font(.title)
                            Text("Complete")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.green)
                    .disabled(!isRecording)
                    .opacity(!isRecording ? 0.5 : 1)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(isRecording)
        .navigationTitle("Recording Climb")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func toggleRecording() {
        isRecording.toggle()
        
        if isRecording {
            // start timer
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                elapsedTime += 0.1
            }
            // TODO: start video recording
        } else {
            // stop timer
            timer?.invalidate()
            timer = nil
            // TODO: stop video recording
        }
    }
    
    private func restartAttempt() {
        attemptCount += 1
        elapsedTime = 0
        // TODO: restart recording
    }
    
    private func completeClimb() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        Task {
            await submitClimbEvent()
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let deciseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, deciseconds)
    }
    
    @MainActor
    private func submitClimbEvent() async {
        let body = ReadSessionRequest.ClimbEventBody(
            status: .completed,
            attempts: attemptCount,
            durationSeconds: Int(elapsedTime)
        )
        
        do {
            _ = try await ReadSessionRequest.addClimbEvent(userId: currentUserId, body: body)
        } catch {
            // ignore errors for now; session updates are non-blocking
        }
    }
}

struct PoseSkeletonOverlay: View {
    var body: some View {
        // placeholder for real-time pose detection overlay
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            
            // simple skeleton placeholder
            Path { path in
                // head to neck
                path.move(to: CGPoint(x: centerX, y: centerY - 100))
                path.addLine(to: CGPoint(x: centerX, y: centerY - 70))
                
                // shoulders
                path.move(to: CGPoint(x: centerX - 30, y: centerY - 60))
                path.addLine(to: CGPoint(x: centerX + 30, y: centerY - 60))
                
                // spine
                path.move(to: CGPoint(x: centerX, y: centerY - 70))
                path.addLine(to: CGPoint(x: centerX, y: centerY + 30))
                
                // left arm
                path.move(to: CGPoint(x: centerX - 30, y: centerY - 60))
                path.addLine(to: CGPoint(x: centerX - 60, y: centerY - 20))
                
                // right arm
                path.move(to: CGPoint(x: centerX + 30, y: centerY - 60))
                path.addLine(to: CGPoint(x: centerX + 60, y: centerY - 20))
                
                // left leg
                path.move(to: CGPoint(x: centerX, y: centerY + 30))
                path.addLine(to: CGPoint(x: centerX - 20, y: centerY + 80))
                
                // right leg
                path.move(to: CGPoint(x: centerX, y: centerY + 30))
                path.addLine(to: CGPoint(x: centerX + 20, y: centerY + 80))
            }
            .stroke(Color.green, lineWidth: 3)
        }
    }
}

#Preview {
    NavigationView {
        ClimbRecordingView()
    }
}
