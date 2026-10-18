import AppModels
import Foundation
import Testing

struct SXJBlockRuleTests {
    private var gallery: Gallery {
        Gallery(
            gid: "1", token: "token", title: "A sample title", rating: 0,
            tags: [.init(rawNamespace: "language", contents: [
                .init(rawNamespace: "language", text: "english", isVotedUp: false, isVotedDown: false)
            ])],
            category: .manga, uploader: "Example", pageCount: 1, postedDate: Date(),
            coverURL: nil, galleryURL: nil
        )
    }

    @Test func titleMatchesCaseInsensitiveSubstring() {
        #expect(SXJBlockRule(kind: .title, value: "SAMPLE").matches(gallery))
    }

    @Test func uploaderUsesExactMatch() {
        #expect(SXJBlockRule(kind: .uploader, value: "example").matches(gallery))
        #expect(!SXJBlockRule(kind: .uploader, value: "exam").matches(gallery))
    }

    @Test func tagNamespacePreventsCrossNamespaceMatch() {
        #expect(SXJBlockRule(kind: .tag, value: "language:english").matches(gallery))
        #expect(!SXJBlockRule(kind: .tag, value: "artist:english").matches(gallery))
        #expect(SXJBlockRule(kind: .namespace, value: "language").matches(gallery))
    }

    @Test func blankAndDisabledRulesDoNotHideContent() {
        #expect(!SXJBlockRule(kind: .title, value: "   ").matches(gallery))
        #expect(!SXJBlockRule(kind: .uploader, value: "Example", isEnabled: false).matches(gallery))
    }
}
