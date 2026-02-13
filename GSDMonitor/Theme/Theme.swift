import SwiftUI

// MARK: - Project Color Mapping

enum ProjectColors {
    private static let rainbow: [(dark: Color, bright: Color)] = [
        (Theme.red, Theme.brightRed),
        (Theme.orange, Theme.brightOrange),
        (Theme.yellow, Theme.brightYellow),
        (Theme.green, Theme.brightGreen),
        (Theme.aqua, Theme.brightAqua),
        (Theme.blue, Theme.brightBlue),
        (Theme.purple, Theme.brightPurple),
    ]

    static func forIndex(_ index: Int) -> (dark: Color, bright: Color) {
        rainbow[index % rainbow.count]
    }

    static func forName(_ name: String) -> (dark: Color, bright: Color) {
        let index = Int(name.lowercased().first?.asciiValue ?? 0) % rainbow.count
        return rainbow[index]
    }
}

// MARK: - Color Extension for Hex Initialization

extension Color {
    /// Initialize a Color from a hex string (e.g., "#282828")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gruvbox Dark Theme

enum Theme {
    // MARK: Background Colors

    static let bg0 = Color(hex: "#282828")
    static let bg0Hard = Color(hex: "#1d2021")
    static let bg0Soft = Color(hex: "#32302f")
    static let bg1 = Color(hex: "#3c3836")
    static let bg2 = Color(hex: "#504945")
    static let bg3 = Color(hex: "#665c54")
    static let bg4 = Color(hex: "#7c6f64")

    // MARK: Foreground Colors

    static let fg0 = Color(hex: "#fbf1c7")
    static let fg1 = Color(hex: "#ebdbb2")
    static let fg2 = Color(hex: "#d5c4a1")
    static let fg3 = Color(hex: "#bdae93")
    static let fg4 = Color(hex: "#a89984")

    // MARK: Accent Colors (Normal)

    static let red = Color(hex: "#cc241d")
    static let green = Color(hex: "#98971a")
    static let yellow = Color(hex: "#d79921")
    static let blue = Color(hex: "#458588")
    static let purple = Color(hex: "#b16286")
    static let aqua = Color(hex: "#689d6a")
    static let orange = Color(hex: "#d65d0e")
    static let gray = Color(hex: "#928374")

    // MARK: Accent Colors (Bright)

    static let brightRed = Color(hex: "#fb4934")
    static let brightGreen = Color(hex: "#b8bb26")
    static let brightYellow = Color(hex: "#fabd2f")
    static let brightBlue = Color(hex: "#83a598")
    static let brightPurple = Color(hex: "#d3869b")
    static let brightAqua = Color(hex: "#8ec07c")
    static let brightOrange = Color(hex: "#fe8019")

    // MARK: Semantic Aliases - Status Colors

    /// In progress / active tasks
    static let statusActive = yellow

    /// Completed tasks
    static let statusComplete = green

    /// Not started tasks (gray)
    static let statusNotStarted = fg4

    /// Blocked tasks
    static let statusBlocked = red

    /// Cancelled phases (strikethrough red)
    static let statusCancelled = red

    /// Deferred phases (moved to later milestone)
    static let statusDeferred = orange

    // MARK: Semantic Aliases - Requirement Status

    static let requirementActive = blue
    static let requirementValidated = green
    static let requirementDeferred = orange

    // MARK: Semantic Aliases - UI Elements

    /// Primary text color
    static let textPrimary = fg1

    /// Secondary text color
    static let textSecondary = fg4

    /// Muted text color
    static let textMuted = bg4

    /// Surface background
    static let surface = bg1

    /// Surface hover state
    static let surfaceHover = bg2

    /// Accent color for interactive elements
    static let accent = brightAqua

    /// Warning color
    static let warning = orange

    /// Card background
    static let cardBackground = bg1

    /// Card shadow
    static let cardShadow = Color.black.opacity(0.3)
}
