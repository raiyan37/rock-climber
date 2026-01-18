//
//  LoginView.swift
//  RockClimber
//
//  Created on 2026-01-17
//

import SwiftUI
import GoogleSignIn
import UIKit

struct LoginView: View {
    @AppStorage("authToken") private var authToken = ""
    @AppStorage("currentUserId") private var currentUserId = ""
    @AppStorage("userFirstName") private var userFirstName = ""
    @AppStorage("userLastName") private var userLastName = ""
    @AppStorage("userPhotoURL") private var userPhotoURL = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // app logo/title
            VStack(spacing: 10) {
                Image(systemName: "figure.climbing")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("RockClimber")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your climbing progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // google sign in button placeholder
            Button(action: {
                Task { await handleGoogleSignIn() }
            }) {
                HStack {
                    Image(systemName: "globe")
                        .font(.title2)
                    
                    Text("Sign in with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(10)
                .shadow(radius: 2)
            }
            .padding(.horizontal, 40)
            .disabled(isSigningIn)
            .opacity(isSigningIn ? 0.7 : 1)
            
            Spacer()
        }
        .padding()
        .alert(
            "Google Sign-In Failed",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented { errorMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func handleGoogleSignIn() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        defer { isSigningIn = false }
        
        // testing mode: bypass google oauth and set dummy values to go straight to home
        authToken = "test-token-123"
        currentUserId = "test-user-id"
        userFirstName = "Test"
        userLastName = "User"
        userPhotoURL = ""
        
        // original google oauth code (commented out for testing)
        /*
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String,
              !clientId.isEmpty else {
            errorMessage = "Missing GoogleClientID in Info.plist."
            return
        }
        
        guard let presentingViewController = UIApplication.shared.rootViewController else {
            errorMessage = "Unable to find a presenting view controller."
            return
        }
        
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Missing Google ID token."
                return
            }
            
            do {
                let auth = try await CreateUserRequest.authenticateGoogle(idToken: idToken)
                print("✅ Auth response - firstName: '\(auth.user.firstName)', lastName: '\(auth.user.lastName)'")
                authToken = auth.token
                currentUserId = auth.user.id
                userFirstName = auth.user.firstName
                userLastName = auth.user.lastName
                userPhotoURL = auth.user.photoURL ?? ""
                print("✅ Stored - firstName: '\(userFirstName)', lastName: '\(userLastName)'")
            } catch let apiError as APIError {
                errorMessage = "Server error: \(apiError.message)"
            } catch {
                errorMessage = "Network error: \(error.localizedDescription)"
            }
        } catch {
            // Only show error if user didn't cancel
            if (error as NSError).code != -5 { // GIDSignInError.canceled
                errorMessage = error.localizedDescription
            }
        }
        */
    }
}

#Preview {
    LoginView()
}

private extension UIApplication {
    var rootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
