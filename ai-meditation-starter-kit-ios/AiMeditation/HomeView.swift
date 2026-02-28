//
//  HomeView.swift
//  AiMeditation
//
//  Main meditation experience after authentication.
//

import OpenbaseShared
import SwiftUI

private enum MeditationScreen {
    case create
    case play
}

struct HomeView: View {
    @StateObject private var viewModel = MeditationLibraryViewModel()
    @State private var showLogoutSheet = false
    @State private var meditationDescription = ""
    @State private var screen: MeditationScreen = .create

    var body: some View {
        VStack(spacing: 0) {
            switch screen {
            case .create:
                createScreen
            case .play:
                playbackScreen
            }
        }
        .navigationTitle("Kynd")
        .toolbar {
            if screen == .play {
                ToolbarItem(placement: .topBarLeading) {
                    Button("New") {
                        viewModel.prepareForNewMeditation()
                        meditationDescription = ""
                        screen = .create
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showLogoutSheet = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .sheet(isPresented: $showLogoutSheet) {
            LogoutView()
                .presentationDetents([.medium])
        }
        .alert("Session Complete", isPresented: $viewModel.shouldPromptForNextMeditation) {
            Button("Create New Metta") {
                viewModel.prepareForNewMeditation()
                meditationDescription = ""
                screen = .create
            }
        } message: {
            Text("Ready to create another loving-kindness meditation?")
        }
        .onDisappear {
            viewModel.stopPlayback(resetMs: false)
        }
    }

    private var createScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Create Metta Meditation")
                    .font(.largeTitle.bold())

                Text("Create one loving-kindness (metta) meditation at a time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $meditationDescription)
                    .frame(minHeight: 180)
                    .padding(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
                    )

                Button {
                    let description = meditationDescription
                    Task {
                        await viewModel.createMeditation(description: description)
                        if viewModel.selectedMeditation?.status == .ready {
                            screen = .play
                        }
                    }
                } label: {
                    if viewModel.isCreatingMeditation || viewModel.isPollingMeditationStatus {
                        Label("Generating...", systemImage: "hourglass")
                    } else {
                        Label("Generate Metta Meditation", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    meditationDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        viewModel.isCreatingMeditation ||
                        viewModel.isPollingMeditationStatus
                )

                if viewModel.isCreatingMeditation || viewModel.isPollingMeditationStatus {
                    ProgressView("Generating metta script and .wav file...")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(20)
        }
    }

    private var playbackScreen: some View {
        Group {
            if let meditation = viewModel.selectedMeditation {
                ZStack {
                    MeditationPlaybackVisualView(isPlaying: viewModel.isPlaying)
                        .ignoresSafeArea()

                    VStack(spacing: 18) {
                        Spacer()

                        VStack(spacing: 6) {
                            Text(meditation.shortDisplayTitle)
                                .font(.title2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                            Text("Kynd Metta Session")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.85))
                            Text("\(viewModel.currentMs / 1000)s / \(meditation.durationMs / 1000)s seconds")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        Button {
                            if viewModel.isPlaying {
                                viewModel.stopPlayback(resetMs: true)
                            } else {
                                viewModel.playSelectedMeditation()
                            }
                        } label: {
                            Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 96, height: 96)
                                .background(Color.white.opacity(0.16))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)

                        if viewModel.isAudioLoading {
                            VStack(spacing: 6) {
                                ProgressView()
                                    .tint(.white)
                                Text("Loading .wav audio...")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        } else if viewModel.isPlaying {
                            Text("Playing")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.85))
                        } else {
                            Text("Ready")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.85))
                        }

                        Spacer()

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 14) {
                    Text("No metta meditation is ready.")
                        .font(.headline)
                    Button("Create New") {
                        screen = .create
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}

private struct MeditationPlaybackVisualView: View {
    let isPlaying: Bool
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.18, blue: 0.32),
                    Color(red: 0.06, green: 0.12, blue: 0.2),
                    Color(red: 0.03, green: 0.05, blue: 0.1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(isPlaying ? 0.32 : 0.2),
                                Color.blue.opacity(0.04),
                            ],
                            center: .center,
                            startRadius: 12,
                            endRadius: 240
                        )
                    )
                    .scaleEffect(isAnimating ? 1 + CGFloat(index) * 0.18 : 0.88 + CGFloat(index) * 0.12)
                    .rotationEffect(.degrees(isAnimating ? Double(index) * 24 : -Double(index) * 16))
                    .blur(radius: CGFloat(index) * 1.8)
            }

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.5),
                            Color.cyan.opacity(0.4),
                            Color.blue.opacity(0.25),
                            Color.white.opacity(0.5),
                        ],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .padding(42)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: isPlaying ? 7 : 10).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
