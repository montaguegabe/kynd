//
//  AiMeditationApp.swift
//  AiMeditation
//
//  AI Meditation iOS app
//

import OpenbaseShared
import SwiftUI
import SwiftyJSON

@main
struct AiMeditationApp: App {
    @StateObject private var authContext = AuthContext.shared

    init() {
        // Configure the AllAuth client
        AllAuthClient.shared.setup(baseUrl: Constants.allAuthUrl)
    }

    var body: some Scene {
        WindowGroup {
            AllAuthRootView(
                authenticatedContent: { AuthenticatedRootView() }
            )
            .environmentObject(authContext)
            .task {
                await authContext.initialize()
            }
        }
    }
}

/// View shown when user is authenticated
struct AuthenticatedRootView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            HomeView()
                .navigationDestination(for: AuthRoute.self) { route in
                    AllAuthAccountDestinations(route: route)
                }
        }
    }
}

#Preview {
    AllAuthRootView(authenticatedContent: { AuthenticatedRootView() })
        .environmentObject(AuthContext.shared)
}
