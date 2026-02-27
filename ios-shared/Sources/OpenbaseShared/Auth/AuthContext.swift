import Foundation
import SwiftUI
import SwiftyJSON
import Combine

/// Manages global authentication state throughout the app
/// Equivalent to AuthContext.js in the React implementation
@MainActor
public class AuthContext: ObservableObject {
    public static let shared = AuthContext()

    // MARK: - Published Properties

    /// Current authentication response from the server
    @Published public var auth: JSON?

    /// Server configuration
    @Published public var config: JSON?

    /// Whether initial loading is complete
    @Published public var isLoading: Bool = true

    /// Last auth change event
    @Published public var lastAuthChange: AuthChangeEvent?

    // MARK: - Computed Properties

    /// Whether the user is authenticated
    public var isAuthenticated: Bool {
        return auth?.isAuthenticated ?? false
    }

    /// Whether reauthentication is required
    public var requiresReauthentication: Bool {
        guard let auth = auth else { return false }
        let status = auth["status"].intValue
        if status == 401 {
            let flows = auth["data"]["flows"].arrayValue
            return flows.contains { flow in
                flow["id"].string == AuthFlow.reauthenticate.rawValue ||
                flow["id"].string == AuthFlow.mfaReauthenticate.rawValue
            }
        }
        return false
    }

    /// Current user data
    public var user: JSON? {
        return auth?.user
    }

    /// Pending flows that require user action
    public var pendingFlows: [JSON] {
        return auth?["data"]["flows"].arrayValue.filter { $0["is_pending"].boolValue } ?? []
    }

    /// Check if a specific flow is pending
    public func isPending(flow: AuthFlow) -> Bool {
        return pendingFlows.contains { $0["id"].string == flow.rawValue }
    }

    /// Get specific pending flow
    public func getPendingFlow(_ flow: AuthFlow) -> JSON? {
        return pendingFlows.first { $0["id"].string == flow.rawValue }
    }

    /// Available MFA types for current flow
    public var availableMFATypes: [String] {
        guard let mfaFlow = getPendingFlow(.mfaAuthenticate) ?? getPendingFlow(.mfaReauthenticate) else {
            return []
        }
        return mfaFlow["types"].arrayValue.map { $0.stringValue }
    }

    // MARK: - Private Properties

    private let client = AllAuthClient.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupAuthChangeListener()
    }

    private func setupAuthChangeListener() {
        client.$lastAuthChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.lastAuthChange = event
            }
            .store(in: &cancellables)

        client.$lastAuthResponse
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                if let response = response {
                    self?.handleAuthResponse(response)
                }
            }
            .store(in: &cancellables)
    }

    private func handleAuthResponse(_ response: JSON) {
        // Update auth state based on response status
        let status = response["status"].intValue
        if status == 200 || status == 401 {
            self.auth = response
        }
    }

    // MARK: - Public Methods

    /// Initialize auth state by fetching config and current auth
    public func initialize() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let configTask = client.getConfig()
            async let authTask = client.getAuth()

            let (configResult, authResult) = try await (configTask, authTask)
            self.config = configResult
            self.auth = authResult
        } catch {
            print("Failed to initialize auth: \(error)")
        }
    }

    /// Refresh current auth state
    public func refreshAuth() async {
        do {
            let result = try await client.getAuth()
            self.auth = result
        } catch {
            print("Failed to refresh auth: \(error)")
        }
    }

    /// Refresh config
    public func refreshConfig() async {
        do {
            let result = try await client.getConfig()
            self.config = result
        } catch {
            print("Failed to refresh config: \(error)")
        }
    }

    /// Clear auth state (used on logout)
    public func clearAuth() {
        auth = nil
    }
}

// MARK: - Config Helpers

extension AuthContext {
    /// Whether email authentication is enabled
    public var emailAuthEnabled: Bool {
        return config?["data"]["account"]["authentication_method"].string != "username"
    }

    /// Whether username authentication is enabled
    public var usernameAuthEnabled: Bool {
        let method = config?["data"]["account"]["authentication_method"].string
        return method == "username" || method == "username_email"
    }

    /// Whether signup is allowed
    public var signupAllowed: Bool {
        return config?["data"]["account"]["is_open_for_signup"].bool ?? true
    }

    /// Whether login by code is enabled
    public var loginByCodeEnabled: Bool {
        return config?["data"]["account"]["login_by_code_enabled"].bool ?? false
    }

    /// Whether MFA is enabled
    public var mfaEnabled: Bool {
        return config?["data"]["mfa"]["enabled"].bool ?? false
    }

    /// Available social providers
    public var socialProviders: [JSON] {
        return config?["data"]["socialaccount"]["providers"].arrayValue ?? []
    }

    /// Get provider by ID
    public func provider(byId id: String) -> JSON? {
        return socialProviders.first { $0["id"].string == id }
    }
}

// MARK: - Auth Change Detection

extension AuthContext {
    /// Determine what type of auth change occurred
    public func detectAuthChange(from previousAuth: JSON?, to currentAuth: JSON?) -> AuthChangeEvent? {
        let wasAuthenticated = previousAuth?["meta"]["is_authenticated"].bool ?? false
        let isNowAuthenticated = currentAuth?["meta"]["is_authenticated"].bool ?? false
        let currentStatus = currentAuth?["status"].intValue ?? 0

        if !wasAuthenticated && isNowAuthenticated && currentStatus == 200 {
            return .loggedIn
        }

        if wasAuthenticated && !isNowAuthenticated && currentStatus == 401 {
            return .loggedOut
        }

        if currentStatus == 401 {
            let flows = currentAuth?["data"]["flows"].arrayValue ?? []
            let hasReauthFlow = flows.contains { flow in
                flow["id"].string == AuthFlow.reauthenticate.rawValue ||
                flow["id"].string == AuthFlow.mfaReauthenticate.rawValue
            }
            if hasReauthFlow {
                return .reauthenticationRequired
            }
        }

        if currentStatus == 200 && currentAuth?["data"]["flows"].exists() == true {
            return .flowUpdated
        }

        return nil
    }
}
