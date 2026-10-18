import Sharing

public struct SXJReaderOptions: Codable, Equatable, Sendable {
    public var keepsScreenAwake = true
    public var usesCustomBrightness = false
    public var brightness = 0.5
    public var showsPageNumber = true
    public var showsTime = false
    public var showsBattery = false
    public var background = Background.system

    public init() {}

    public enum Background: String, Codable, CaseIterable, Identifiable, Sendable {
        case system
        case black
        case white

        public var id: String { rawValue }
    }

    public var normalizedBrightness: Double { min(max(brightness, 0.05), 1) }
}

extension SharedKey where Self == AppStorageKey<SXJReaderOptions>.Default {
    public static var sxjReaderOptions: Self {
        Self[.appStorage("sxjReaderOptions"), default: SXJReaderOptions()]
    }
}
