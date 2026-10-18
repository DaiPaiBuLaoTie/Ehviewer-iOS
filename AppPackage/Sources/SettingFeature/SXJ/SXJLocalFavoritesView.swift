import AppModels
import ComposableArchitecture
import DetailFeature
import GalleryListComponents
import Sharing
import SFSafeSymbols
import SwiftUI

struct SXJLocalFavoritesView: View {
    @Environment(\.scenePhase) private var scenePhase
    @SharedReader(.setting) private var setting: Setting
    @State private var store = Store(
        initialState: SXJLocalFavoritesFeature.State(), reducer: SXJLocalFavoritesFeature.init
    )

    var body: some View {
        GalleryNavigationContainer(
            store: store, state: \.path, action: \.path, blurRadius: setting.backgroundBlurRadius
        ) {
            content
                .navigationTitle("本地收藏")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.send(.flushReading) }
        }
    }

    private var content: some View {
        @Bindable var store = store
        return GenericList(
            galleries: store.filteredFavorites, pageNumber: nil,
            loadingState: .idle, footerLoadingState: .idle,
            navigateAction: { store.send(.openGallery($0)) }
        )
        .searchable(text: $store.keyword, prompt: "搜索本地收藏")
        .overlay {
            if store.favorites.isEmpty {
                ContentUnavailableView("暂无本地收藏", systemSymbol: .bookmark, description: Text("长按画廊可加入本地收藏。"))
            }
        }
    }
}
