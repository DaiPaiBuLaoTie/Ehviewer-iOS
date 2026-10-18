import AppModels
import ComposableArchitecture
import DetailFeature
import Sharing
import SwiftUI

@Reducer
struct SXJLocalFavoritesFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.sxjLocalFavorites) var favorites: [Gallery]
        var path = StackState<GalleryPath.State>()
        var keyword = ""

        var filteredFavorites: [Gallery] {
            guard !keyword.isEmpty else { return favorites }
            return favorites.filter { $0.title.localizedCaseInsensitiveContains(keyword) }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case path(StackActionOf<GalleryPath>)
        case openGallery(Gallery)
        case flushReading
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .openGallery(let gallery):
                state.path.appendGuardingDuplicate(.detail(.init(gallery: gallery)))
                return .none
            case let .path(.element(_, action: elementAction)):
                if let next = GalleryNavigation.nextScreen(for: elementAction) {
                    state.path.appendGuardingDuplicate(next)
                }
                return .none
            case .flushReading:
                guard let flush = state.path.topReadingFlush else { return .none }
                return .send(.path(.element(id: flush.id, action: flush.action)))
            case .binding, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path, element: GalleryPath.init)
    }
}
