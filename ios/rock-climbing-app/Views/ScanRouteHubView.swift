//
//  ScanRouteHubView.swift
//  RockClimber
//
//  Created on 2026-01-17
//

import SwiftUI

struct ScanRouteHubView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ScanRouteActionCard(
                    title: "Scan with Camera",
                    subtitle: "Capture a wall photo to generate routes",
                    icon: "camera.fill",
                    color: .blue,
                    destination: AnyView(CameraView())
                )
                
                ScanRouteActionCard(
                    title: "Scan from Photos",
                    subtitle: "Pick a wall photo from your library",
                    icon: "photo.fill",
                    color: .purple,
                    destination: AnyView(PhotoLibraryView())
                )
                
                ScanRouteActionCard(
                    title: "Record Climb",
                    subtitle: "Log a climb and track your attempts",
                    icon: "video.fill",
                    color: .green,
                    destination: AnyView(ClimbRecordingView())
                )
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .navigationTitle("Scan Route")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

struct ScanRouteActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(color)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationView {
        ScanRouteHubView()
    }
}
