import ProjectDescription

let project = Project(
    name: "AiMeditation",
    options: .options(
        automaticSchemesOptions: .disabled
    ),
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "E6GA9X89TN",
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release"),
        ]
    ),
    targets: [
        .target(
            name: "AiMeditation",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "com.gabemontague.kynd",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": .string("Kynd"),
                "CFBundleShortVersionString": .string("1.0.1"),
                "CFBundleVersion": .string("1"),
                "UILaunchScreen": .dictionary([
                    "UIColorName": .string(""),
                ]),
            ]),
            sources: ["AiMeditation/**"],
            resources: ["AiMeditation/Assets.xcassets", "AiMeditation/Preview Content/**", "AiMeditation/PrivacyInfo.xcprivacy"],
            dependencies: [
                .external(name: "OpenbaseShared"),
            ],
            settings: .settings(
                base: [
                    "CODE_SIGN_STYLE": "Automatic",
                    "ENABLE_PREVIEWS": "YES",
                ]
            )
        ),
        .target(
            name: "AiMeditationTests",
            destinations: [.iPhone, .iPad],
            product: .unitTests,
            bundleId: "com.gabemontague.kynd.tests",
            deploymentTargets: .iOS("18.0"),
            sources: ["AiMeditationTests/**"],
            dependencies: [
                .target(name: "AiMeditation"),
            ]
        ),
        .target(
            name: "AiMeditationUITests",
            destinations: [.iPhone, .iPad],
            product: .uiTests,
            bundleId: "com.gabemontague.kynd.uitests",
            deploymentTargets: .iOS("18.0"),
            sources: ["AiMeditationUITests/**"],
            dependencies: [
                .target(name: "AiMeditation"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "AiMeditation",
            shared: true,
            buildAction: .buildAction(targets: ["AiMeditation"]),
            testAction: .targets(["AiMeditationTests", "AiMeditationUITests"]),
            runAction: .runAction(configuration: "Debug", executable: "AiMeditation")
        ),
    ]
)
