#if canImport(AppKit)
import AppKit
import LauncherCore

enum Theme {
    enum Family {
        static let text = "Google Sans Flex"
        static let icons = "Material Symbols Rounded"
        static let numbers = "Rubik"
    }

    enum TextSize {
        static let labelMedium: CGFloat = 16
        static let bodySmall: CGFloat = 16
        static let bodyMedium: CGFloat = 19
        static let bodyLarge: CGFloat = 21
    }

    enum IconSize {
        static let medium: CGFloat = 24
        static let large: CGFloat = 32
        static let search: CGFloat = 22
    }

    enum Rounding {
        static let large: CGFloat = 12
        static let extraLarge: CGFloat = 21
    }

    enum Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum Launcher {
        static let contentWidth: CGFloat = 600
        static let padding: CGFloat = Spacing.large
        static let itemHeight: CGFloat = 57
        static let maxRows = 7
        static let appIcon: CGFloat = 46
        static let cardWidth: CGFloat = 280
        static let cardHeight: CGFloat = 200
        static let maxCards = 9
        static let searchVerticalPadding: CGFloat = 14
        static let highlightAlpha: CGFloat = 0.08
        static let dimmedCardAlpha: CGFloat = 0.6
        static let placeholder = "Type \">\" for commands"
    }

    static let animationDuration: TimeInterval = 0.2

    enum Bar {
        static let width: CGFloat = 40
        static let innerRadius: CGFloat = 21
        static let pillWidth: CGFloat = 32
        static let cellWidth: CGFloat = 28
        static let spaceIcon: CGFloat = 18
        static let statusIcon: CGFloat = 20
        static let clockSize: CGFloat = 18
    }

    enum Dashboard {
        static let width: CGFloat = 760
        static let padding: CGFloat = 18
        static let gap: CGFloat = 10
        static let cardRadius: CGFloat = 16
        static let cardPadding: CGFloat = 14
        static let clockWidth: CGFloat = 170
        static let calendarWidth: CGFloat = 210
        static let topRowHeight: CGFloat = 180
        static let bottomRowHeight: CGFloat = 150
        static let height: CGFloat = topRowHeight + gap + bottomRowHeight + 2 * padding
        static let clockSize: CGFloat = 40
        static let smallText: CGFloat = 12
        static let tinyText: CGFloat = 11
        static let dayCell: CGFloat = 22
        static let weatherIcon: CGFloat = 30
        static let artSize: CGFloat = 64
        static let controlSize: CGFloat = 22
        static let temperatureSize: CGFloat = 20
        static let bodyText: CGFloat = 13
        static let gearSize: CGFloat = 18
    }

    enum Glyph {
        static let search = glyph(0xE8B6)
        static let image = glyph(0xE3F4)
        static let wallpaper = glyph(0xE1BC)
    }

    static func glyph(_ codepoint: UInt32) -> String {
        Unicode.Scalar(codepoint).map { String(Character($0)) } ?? ""
    }

    static func font(_ family: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: family,
            .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue],
        ])
        guard let font = NSFont(descriptor: descriptor, size: size), font.familyName == family else {
            return .systemFont(ofSize: size, weight: weight)
        }
        return font
    }

    static func text(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        font(Family.text, size: size, weight: weight)
    }

    static func icon(_ size: CGFloat) -> NSFont {
        font(Family.icons, size: size)
    }

    static func lineHeight(_ font: NSFont) -> CGFloat {
        ceil(font.ascender - font.descender + font.leading)
    }

    static func color(_ palette: Palette, _ role: String, alpha: CGFloat = 1) -> NSColor {
        let rgb = palette[role]
        return NSColor(srgbRed: CGFloat(rgb.r), green: CGFloat(rgb.g), blue: CGFloat(rgb.b), alpha: alpha)
    }
}
#endif
