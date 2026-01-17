//
//  PhotoLibraryView.swift
//  RockClimber
//
//  Created on 2026-01-17
//

import SwiftUI
import PhotosUI
import UIKit

struct PhotoLibraryView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isGeneratingRoute = false
    @State private var routeImage: UIImage?
    @State private var showRouteAnalysis = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            hiddenNavigationLink
            mainContent
        }
        .navigationTitle("Photo Library")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .overlay {
            if isGeneratingRoute {
                loadingOverlay
            }
        }
        .alert(
            "Route generation failed",
            isPresented: errorAlertBinding
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var hiddenNavigationLink: some View {
        NavigationLink(
            destination: RouteAnalysisView(analyzedImage: routeImage),
            isActive: $showRouteAnalysis
        ) {
            EmptyView()
        }
        .hidden()
    }
    
    private var mainContent: some View {
        VStack(spacing: 20) {
            if let selectedImage {
                selectedImageView(selectedImage)
            } else {
                photoPickerView
            }
        }
    }
    
    private func selectedImageView(_ image: UIImage) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(10)
                    .padding()
                
                scanButton(for: image)
                chooseDifferentButton
            }
        }
    }
    
    private func scanButton(for image: UIImage) -> some View {
        Button(action: {
            Task {
                await processImage(image)
            }
        }) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                Text("Scan Route")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .disabled(isGeneratingRoute)
    }
    
    private var chooseDifferentButton: some View {
        Button(action: {
            selectedImage = nil
            selectedItem = nil
        }) {
            Text("Choose Different Photo")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private var photoPickerView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.6))
            
            photoPickerText
            photoPickerButton
            
            Spacer()
        }
    }
    
    private var photoPickerText: some View {
        VStack(spacing: 10) {
            Text("Select a Photo")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Choose a climbing wall photo from your library to scan for routes")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var photoPickerButton: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            HStack {
                Image(systemName: "photo.fill")
                    .font(.title2)
                Text("Browse Photos")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal, 40)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            ProgressView("Generating route…")
                .padding()
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
    
    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )
    }
    
    @MainActor
    private func processImage(_ image: UIImage) async {
        isGeneratingRoute = true
        defer { isGeneratingRoute = false }
        
        do {
            // prepare image for upload (same processing as camera)
            guard let imageData = prepareImageForUpload(image) else {
                errorMessage = "Failed to process image"
                return
            }
            
            let responseData = try await APIClient.shared.uploadMultipart(
                path: "/boulder/generate",
                data: imageData,
                filename: "wall.jpg",
                mimeType: "image/jpeg"
            )
            
            guard let resultImage = UIImage(data: responseData) else {
                errorMessage = "Invalid image returned by server"
                return
            }
            
            routeImage = resultImage
            showRouteAnalysis = true
        } catch let apiError as APIError {
            errorMessage = apiError.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // reuse the same image processing logic from CameraManager
    private func prepareImageForUpload(_ image: UIImage) -> Data? {
        let normalized = image.normalized()
        let resized = normalized.resizedToMaxWidth(1216)
        
        let maxBytes = 4 * 1024 * 1024
        var quality: CGFloat = 0.85
        var jpegData = resized.jpegData(compressionQuality: quality)
        
        while let data = jpegData, data.count > maxBytes, quality > 0.25 {
            quality -= 0.1
            jpegData = resized.jpegData(compressionQuality: quality)
        }
        
        guard let data = jpegData, data.count <= maxBytes else {
            return nil
        }
        
        return data
    }
}

// image processing extensions (same as in CameraManager)
private extension UIImage {
    func normalized() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func resizedToMaxWidth(_ maxWidth: CGFloat) -> UIImage {
        guard size.width > 0 else { return self }
        
        let scale = min(1, maxWidth / size.width)
        if scale == 1 {
            return self
        }
        
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

#Preview {
    NavigationView {
        PhotoLibraryView()
    }
}
