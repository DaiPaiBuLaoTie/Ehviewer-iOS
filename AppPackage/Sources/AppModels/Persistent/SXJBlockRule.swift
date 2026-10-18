import Foundation
import Sharing

/// A local rule. Server-side account filters remain independent.
public struct SXJBlockRule: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case title
        case uploader
        case tag
        case namespace
    }

    public var id: UUID
    public var kind: Kind
    public var value: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), kind: Kind, value: String, isEnabled: Bool = true) {
        self.id = id
        self.kind = kind
        self.value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isEnabled = isEnabled
    }

    public func matches(_ gallery: Gallery) -> Bool {
        guard isEnabled, !value.isEmpty else { return false }
        switch kind {
        case .title:
            return gallery.title.localizedCaseInsensitiveContains(value)
        case .uploader:
            return gallery.uploader?.caseInsensitiveCompare(value) == .orderedSame
        case .namespace:
            return gallery.tags.contains { $0.rawNamespace.caseInsensitiveCompare(value) == .orderedSame }
        case .tag:
            let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
            return gallery.tags.contains { group in
                guard parts.count == 1
                    || group.rawNamespace.caseInsensitiveCompare(parts[0]) == .orderedSame
                else { return false }
                let expected = parts.last ?? value
                return group.contents.contains { $0.text.caseInsensitiveCompare(expected) == .orderedSame }
            }
        }
    }
}

extension SharedKey where Self == AppStorageKey<[SXJBlockRule]>.Default {
    public static var sxjBlockRules: Self {
        Self[.appStorage("sxjBlockRules"), default: []]
    }
}
