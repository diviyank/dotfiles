import Foundation

public struct SchemePreset: Equatable {
    public let name: String
    public let title: String
    public let seed: String?
}

public let schemePresets = [
    SchemePreset(name: "dynamic", title: "Dynamic", seed: nil),
    SchemePreset(name: "catppuccin", title: "Catppuccin", seed: "#cba6f7"),
    SchemePreset(name: "dracula", title: "Dracula", seed: "#bd93f9"),
    SchemePreset(name: "everforest", title: "Everforest", seed: "#a7c080"),
    SchemePreset(name: "gruvbox", title: "Gruvbox", seed: "#d79921"),
    SchemePreset(name: "nord", title: "Nord", seed: "#88c0d0"),
    SchemePreset(name: "onedark", title: "One Dark", seed: "#61afef"),
    SchemePreset(name: "rosepine", title: "Rosé Pine", seed: "#c4a7e7"),
    SchemePreset(name: "tokyonight", title: "Tokyo Night", seed: "#7aa2f7"),
]

public struct SchemeVariant: Equatable {
    public let type: String
    public let title: String
}

public let schemeVariants = [
    SchemeVariant(type: "scheme-tonal-spot", title: "Tonal spot"),
    SchemeVariant(type: "scheme-content", title: "Content"),
    SchemeVariant(type: "scheme-expressive", title: "Expressive"),
    SchemeVariant(type: "scheme-fidelity", title: "Fidelity"),
    SchemeVariant(type: "scheme-fruit-salad", title: "Fruit salad"),
    SchemeVariant(type: "scheme-monochrome", title: "Monochrome"),
    SchemeVariant(type: "scheme-neutral", title: "Neutral"),
    SchemeVariant(type: "scheme-rainbow", title: "Rainbow"),
]

public struct SchemeState: Codable, Equatable, Sendable {
    public var name: String
    public var variant: String
    public var mode: String

    public init(name: String = "dynamic", variant: String = "scheme-tonal-spot", mode: String = "dark") {
        self.name = name
        self.variant = variant
        self.mode = mode
    }

    public var seed: String? { schemePresets.first { $0.name == name }?.seed }

    private enum CodingKeys: String, CodingKey { case name, variant, mode, seed }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SchemeState()
        name = (try? container.decode(String.self, forKey: .name)) ?? defaults.name
        variant = (try? container.decode(String.self, forKey: .variant)) ?? defaults.variant
        mode = (try? container.decode(String.self, forKey: .mode)) ?? defaults.mode
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(variant, forKey: .variant)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(seed, forKey: .seed)
    }
}

public func loadSchemeState(_ url: URL) -> SchemeState {
    guard let data = try? Data(contentsOf: url) else { return SchemeState() }
    return (try? JSONDecoder().decode(SchemeState.self, from: data)) ?? SchemeState()
}

public func saveSchemeState(_ state: SchemeState, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(state).write(to: url, options: .atomic)
}

public func matugenPreviewArguments(_ state: SchemeState, source: URL) -> [String] {
    let input = state.seed.map { ["color", "hex", $0] } ?? ["image", source.path]
    return input + ["-t", state.variant, "-m", state.mode, "--dry-run", "-j", "hex", "-q"]
}
