import SwiftUI

/// Tokens issus de DESIGN.md. Aucune couleur ni police n'est définie ailleurs.
enum Theme {

    // MARK: - Identité parapluie (DESIGN.md §2.1)

    enum Umbrella {
        static let paper = Color(light: 0xFAF8F3, dark: 0x14120E)
        static let ink = Color(light: 0x1A1A1A, dark: 0xF2EFE8)
        static let inkSecondary = Color(light: 0x5C5A55, dark: 0xA8A49A)
        static let rule = Color(light: 0xE3DED3, dark: 0x33302A)
    }

    enum Accent {
        static let airHockey = Color(hex: 0xFF2A6D)
        static let chess = Color(light: 0x1A1A1A, dark: 0xF2EFE8)
        static let draughts = Color(hex: 0xC8A063)
        static let tron = Color(hex: 0x05D9E8)
        static let mill = Color(hex: 0x1E3A5F)
    }

    // MARK: - Matières (DESIGN.md §3, §4)

    enum Wood {
        static let wood = Color(light: 0xC8A063, dark: 0x6B5535)
        static let felt = Color(light: 0x1E3A5F, dark: 0x2C4A70)
        static let paper = Color(light: 0xF2E8D5, dark: 0x2A251C)
        static let brass = Color(light: 0xB08D57, dark: 0xC9A468)
        static let hit = Color(light: 0xC0392B, dark: 0xE0503F)
    }

    enum Arcade {
        static let void_ = Color(hex: 0x0D0221)
        static let magenta = Color(hex: 0xFF2A6D)
        static let cyan = Color(hex: 0x05D9E8)
        static let amber = Color(hex: 0xF9F002)
    }

    // MARK: - Typographie (DESIGN.md §2.2)

    enum Typo {
        /// Zilla Slab ne descend jamais sous 20 pt. Suit le Dynamic Type via un style de référence,
        /// choisi selon la taille de base pour que l'échelle reste cohérente.
        static func display(_ size: CGFloat, weight: DisplayWeight = .bold) -> Font {
            let base = max(size, 20)
            let reference: Font.TextStyle = switch base {
            case ..<24: .title3
            case ..<30: .title2
            case ..<40: .title
            default: .largeTitle
            }
            return .custom(weight.postScriptName, size: base, relativeTo: reference)
        }

        /// Score arcade : suit aussi le Dynamic Type, mais reste hors plateau de jeu.
        static func score(_ size: CGFloat) -> Font {
            .custom("Orbitron-Regular", size: size, relativeTo: size >= 30 ? .largeTitle : .body)
        }

        enum DisplayWeight {
            case regular, semibold, bold
            var postScriptName: String {
                switch self {
                case .regular: "ZillaSlab-Regular"
                case .semibold: "ZillaSlab-SemiBold"
                case .bold: "ZillaSlab-Bold"
                }
            }
        }
    }

    // MARK: - Espacement et formes (DESIGN.md §2.3)

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let control: CGFloat = 8
        static let surface: CGFloat = 16
        static let sheet: CGFloat = 28
    }

    /// Marge de sécurité de part et d'autre du pli (FOLDABLE.md Q3).
    static let foldGutter: CGFloat = 24
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Couleur qui suit l'apparence claire ou sombre effective.
    init(light: UInt32, dark: UInt32) {
        self = Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// Préférence d'apparence, choisie dans les réglages.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var localizationKey: String { "appearance.\(rawValue)" }

    static var current: Appearance {
        Appearance(rawValue: UserDefaults.standard.string(forKey: "settings.appearance") ?? "") ?? .system
    }
}

/// Langue de l'app, choisie à l'onboarding puis modifiable dans les réglages.
/// Par défaut « système » : l'app suit la langue de l'appareil parmi les cinq disponibles.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, fr, es, it, de
    var id: String { rawValue }

    /// Locale à imposer, ou `nil` pour suivre l'appareil.
    var locale: Locale? {
        self == .system ? nil : Locale(identifier: rawValue)
    }

    /// Nom affiché dans sa propre langue.
    var nativeName: String {
        switch self {
        case .system: "—"
        case .en: "English"
        case .fr: "Français"
        case .es: "Español"
        case .it: "Italiano"
        case .de: "Deutsch"
        }
    }

    var flag: String {
        switch self {
        case .system: "globe"
        case .en: "🇬🇧"
        case .fr: "🇫🇷"
        case .es: "🇪🇸"
        case .it: "🇮🇹"
        case .de: "🇩🇪"
        }
    }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "settings.language") ?? "") ?? .system
    }
}

// MARK: - Composants de base

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.Umbrella.ink
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.Umbrella.paper)
            .padding(.vertical, Theme.Space.m)
            .padding(.horizontal, Theme.Space.l)
            .frame(maxWidth: .infinity)
            .background(tint, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
            .opacity(!isEnabled ? 0.35 : (configuration.isPressed ? 0.85 : 1))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.Umbrella.ink)
            .padding(.vertical, Theme.Space.m)
            .padding(.horizontal, Theme.Space.l)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .stroke(Theme.Umbrella.rule, lineWidth: 1.5)
            )
            .opacity(!isEnabled ? 0.35 : (configuration.isPressed ? 0.7 : 1))
    }
}
