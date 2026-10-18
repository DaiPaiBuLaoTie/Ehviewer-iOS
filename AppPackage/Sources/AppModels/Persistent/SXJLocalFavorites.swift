import Sharing

extension SharedKey where Self == AppStorageKey<[Gallery]>.Default {
    public static var sxjLocalFavorites: Self {
        Self[.appStorage("sxjLocalFavorites"), default: []]
    }
}
