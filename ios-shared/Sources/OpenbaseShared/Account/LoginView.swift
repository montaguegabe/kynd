import Foundation
import SwiftUI
import SwiftyJSON

/// Login view
/// Equivalent to Login.js in the React implementation
public struct LoginView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared
    private let onShake: (() -> Void)?

    public init(onShake: (() -> Void)? = nil) {
        self.onShake = onShake
    }

    public var body: some View {
        AuthForm(title: "Sign In", subtitle: "Welcome back! Please sign in to continue.") {
            VStack(spacing: 16) {
                // Email or Username field based on config
                if authContext.emailAuthEnabled {
                    EmailField(text: $email, errors: response)
                }

                if authContext.usernameAuthEnabled {
                    UsernameField(text: $username, errors: response)
                }

                PasswordField(text: $password, errors: response)

                // General errors
                FormErrors(errors: response)

                // Login button
                PrimaryButton(title: "Sign In", isLoading: isLoading) {
                    await login()
                }

                // Links
                VStack(spacing: 12) {
                    if authContext.loginByCodeEnabled {
                        LinkButton(title: "Sign in with a code instead") {
                            navigationManager.navigate(to: .confirmLoginCode)
                        }
                    }

                    LinkButton(title: "Forgot password?") {
                        navigationManager.navigate(to: .requestPasswordReset)
                    }

                    if authContext.signupAllowed {
                        HStack {
                            Text("Don't have an account?")
                                .foregroundColor(.secondary)
                            LinkButton(title: "Sign up") {
                                navigationManager.navigate(to: .signup)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .onShake {
            onShake?()
        }
    }

    private func login() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if authContext.emailAuthEnabled && !email.isEmpty {
                response = try await client.login(email: email, password: password)
            } else {
                response = try await client.login(username: username, password: password)
            }

            if response?.isSuccess == true {
                // Navigation handled by auth context observer
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - Shake Gesture Detection

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

struct ShakeDetector: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                action()
            }
    }
}

public extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeDetector(action: action))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}
