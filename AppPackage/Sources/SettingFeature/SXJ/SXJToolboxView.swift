import AppModels
import AppTools
import Sharing
import SwiftUI
import UniformTypeIdentifiers

struct SXJToolboxView: View {
    @Shared(.setting) private var setting: Setting
    @Shared(.searchFilter) private var searchFilter: Filter
    @Shared(.globalFilter) private var globalFilter: Filter
    @Shared(.watchedFilter) private var watchedFilter: Filter
    @Shared(.historyKeywords) private var historyKeywords: [String]
    @Shared(.quickSearchWords) private var quickSearchWords: [QuickSearchWord]
    @Shared(.galleryHistory) private var galleryHistory: [GalleryHistoryEntry]
    @Shared(.sxjBlockRules) private var blockRules: [SXJBlockRule]
    @Shared(.sxjLocalFavorites) private var localFavorites: [Gallery]
    @Shared(.sxjReaderOptions) private var readerOptions: SXJReaderOptions
    @State private var showingFavorites = false
    @State private var exporting = false
    @State private var importing = false
    @State private var confirmingImport = false
    @State private var document = SXJBackupDocument()
    @State private var pendingBackup: SXJBackup?
    @State private var status: String?

    var body: some View {
        Form {
            Section("站点与账号") {
                sitePage("标签订阅与屏蔽", path: "mytags")
                sitePage("站点配置", path: "uconfig.php")
                sitePage("配额、积分与账号信息", path: "home.php")
                NavigationLink("站点新闻") { WebView(url: Defaults.URL.news).navigationTitle("站点新闻") }
                NavigationLink("论坛") { WebView(url: Defaults.URL.forum).navigationTitle("论坛") }
            }
            Section("本地管理") {
                Button("本地收藏") { showingFavorites = true }
                    .sheet(isPresented: $showingFavorites) { SXJLocalFavoritesView() }
                NavigationLink("标题、上传者和标签屏蔽") { SXJBlockRulesView() }
                NavigationLink("本地画廊导入") { SXJLocalImportView() }
                NavigationLink("Android 数据库迁移") { SXJAndroidMigrationView() }
                NavigationLink("网络与自定义 Hosts") { SXJNetworkView() }
            }
            Section("数据备份") {
                Button("导出设置、历史和快速搜索") { exportBackup() }
                    .fileExporter(
                        isPresented: $exporting, document: document,
                        contentType: .json, defaultFilename: "EhViewer-SXJ-backup"
                    ) { result in
                        if case .failure(let error) = result { status = error.localizedDescription }
                    }
                Button(pendingBackup == nil ? "选择备份文件" : "确认恢复已选择的备份") {
                    if pendingBackup == nil { importing = true } else { confirmingImport = true }
                }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                    importBackup(result)
                }
                .confirmationDialog("恢复将覆盖当前设置、历史和快速搜索。", isPresented: $confirmingImport) {
                    Button("恢复备份", role: .destructive) { applyBackup() }
                    Button("取消", role: .cancel) { pendingBackup = nil }
                }
                Text("备份包含设置、筛选、本地屏蔽、历史记录和快速搜索，不包含登录 Cookie 或下载图片。下载文件可通过“文件”应用复制。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let status {
                Section { Text(status).textSelection(.enabled) }
            }
        }
        .navigationTitle("扩展工具")
    }

    private func sitePage(_ title: String, path: String) -> some View {
        NavigationLink(title) {
            WebView(url: setting.galleryHost.url.appendingPathComponent(path)).navigationTitle(title)
        }
    }

    private func exportBackup() {
        do {
            document = try SXJBackupDocument(data: SXJBackup(
                setting: setting, searchFilter: searchFilter, globalFilter: globalFilter,
                watchedFilter: watchedFilter, historyKeywords: historyKeywords,
                quickSearchWords: quickSearchWords, galleryHistory: galleryHistory,
                blockRules: blockRules, localFavorites: localFavorites, readerOptions: readerOptions
            ).encoded())
            exporting = true
            status = nil
        } catch { status = error.localizedDescription }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            var dataResult: Result<Data, Error>?
            var coordinationError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, error: &coordinationError) { localURL in
                dataResult = Result { try Data(contentsOf: localURL) }
            }
            if let coordinationError { throw coordinationError }
            guard let dataResult else { throw CocoaError(.fileReadUnknown) }
            pendingBackup = try SXJBackup.decode(dataResult.get())
            status = "备份已验证。点击确认恢复后才会修改当前数据。"
        } catch { status = error.localizedDescription }
    }

    private func applyBackup() {
        guard let backup = pendingBackup else { return }
        $setting.withLock { $0 = backup.setting }
        $searchFilter.withLock { $0 = backup.searchFilter }
        $globalFilter.withLock { $0 = backup.globalFilter }
        $watchedFilter.withLock { $0 = backup.watchedFilter }
        $historyKeywords.withLock { $0 = Array(backup.historyKeywords.suffix(20)) }
        $quickSearchWords.withLock { $0 = backup.quickSearchWords }
        $galleryHistory.withLock { $0 = Array(backup.galleryHistory.prefix(GalleryHistoryEntry.historyCap)) }
        $blockRules.withLock { $0 = backup.blockRules }
        if let favorites = backup.localFavorites { $localFavorites.withLock { $0 = favorites } }
        if let options = backup.readerOptions { $readerOptions.withLock { $0 = options } }
        pendingBackup = nil
        status = "备份已恢复。请重新打开列表查看更新后的数据。"
    }
}
