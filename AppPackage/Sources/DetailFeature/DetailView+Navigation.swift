import SwiftUI
import Resources
import ComposableArchitecture
import AppTools
import AppComponents
import SFSafeSymbolsExt

// MARK: ToolBar
extension DetailView {
    func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            ToolbarFeaturesMenu {
                Button(localFavorites.contains(where: { $0.gid == gid }) ? "取消本地收藏" : "加入本地收藏") {
                    $localFavorites.withLock { current in
                        if let index = current.firstIndex(where: { $0.gid == gid }) {
                            current.remove(at: index)
                        } else if current.count < 1_000 {
                            current.insert(store.gallery, at: 0)
                        }
                    }
                }
                Button {
                    store.send(.archivesButtonTapped)
                } label: {
                    Label(.archivesAction, systemSymbol: .zipperPage)
                }
                .disabled(store.galleryDetail?.archiveURL == nil || !CookieUtil.didLogin)
                Button {
                    store.send(.torrentsButtonTapped)
                } label: {
                    let torrentCount = store.galleryDetail?.torrentCount ?? 0
                    let title: LocalizedStringResource = torrentCount > 0
                        ? .torrentsCount(count: torrentCount) : .torrents
                    Label(title, systemSymbol: .leaf)
                }
                .disabled((store.galleryDetail?.torrentCount ?? 0 > 0) != true)
                Button {
                    if let galleryURL = store.gallery.galleryURL {
                        store.send(.shareButtonTapped(galleryURL))
                    }
                } label: {
                    Label(.RLocalizable.share, systemSymbol: .squareAndArrowUp)
                }
            }
            .disabled(store.galleryDetail == nil || store.loadingState == .loading)
        }
    }
}
