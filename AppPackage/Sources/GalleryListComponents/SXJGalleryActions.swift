import AppModels
import Sharing
import SwiftUI

struct SXJGalleryActions: View {
    let gallery: Gallery
    @Shared(.sxjLocalFavorites) private var favorites: [Gallery]
    @Shared(.sxjBlockRules) private var rules: [SXJBlockRule]

    private var isSaved: Bool { favorites.contains { $0.gid == gallery.gid } }

    var body: some View {
        Button(isSaved ? "从本地收藏移除" : "加入本地收藏") {
            $favorites.withLock { current in
                if let index = current.firstIndex(where: { $0.gid == gallery.gid }) {
                    current.remove(at: index)
                } else if current.count < 1_000 {
                    current.insert(gallery, at: 0)
                }
            }
        }
        .disabled(!isSaved && favorites.count >= 1_000)
        if let uploader = gallery.uploader, !uploader.isEmpty {
            Button("屏蔽此上传者") { addRule(.uploader, value: uploader) }
        }
        Button("屏蔽此标题") { addRule(.title, value: gallery.title) }
    }

    private func addRule(_ kind: SXJBlockRule.Kind, value: String) {
        guard rules.count < 2_000,
              !rules.contains(where: { $0.kind == kind && $0.value.caseInsensitiveCompare(value) == .orderedSame })
        else { return }
        $rules.withLock { $0.append(.init(kind: kind, value: value)) }
    }
}
