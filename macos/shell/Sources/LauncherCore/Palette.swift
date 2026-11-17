import Foundation

public struct RGB: Equatable {
    public let r, g, b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public struct Palette {
    fileprivate let colors: [String: RGB]

    fileprivate init(colors: [String: RGB]) { self.colors = colors }

    public subscript(role: String) -> RGB {
        colors[role] ?? RGB(r: 1, g: 0, b: 1)
    }
}

private let paletteRoles = [
    "primary", "on_primary", "primary_container", "on_primary_container",
    "secondary", "on_secondary", "secondary_container", "on_secondary_container",
    "tertiary", "on_tertiary", "tertiary_container", "on_tertiary_container",
    "error", "on_error", "surface", "on_surface", "on_surface_variant",
    "surface_container_low", "surface_container", "surface_container_high",
    "surface_container_highest", "outline", "outline_variant", "shadow", "scrim",
]

private let neutralPalette = Palette(colors: Dictionary(
    uniqueKeysWithValues: paletteRoles.map { ($0, RGB(r: 0.5, g: 0.5, b: 0.5)) }
))

private func parseHex(_ text: String) -> RGB? {
    guard text.hasPrefix("#"), text.count == 7, let value = UInt32(text.dropFirst(), radix: 16) else { return nil }
    return RGB(
        r: Double((value >> 16) & 0xff) / 255,
        g: Double((value >> 8) & 0xff) / 255,
        b: Double(value & 0xff) / 255
    )
}

private func readPalette(_ url: URL) -> Palette? {
    guard let data = try? Data(contentsOf: url),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    else { return nil }
    return Palette(colors: json.compactMapValues(parseHex))
}

public func loadPalette(primary: URL, fallback: URL) -> Palette {
    readPalette(primary) ?? readPalette(fallback) ?? neutralPalette
}
