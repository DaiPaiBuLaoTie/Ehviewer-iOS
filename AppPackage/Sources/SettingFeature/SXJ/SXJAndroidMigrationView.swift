import AppModels
import Sharing
import SwiftUI
import UniformTypeIdentifiers

struct SXJAndroidMigrationView: View {
    @SharedReader(.setting) private var setting: Setting
    @Shared(.sxjLocalFavorites) private var favorites: [Gallery]
    @Shared(.galleryHistory) private var history: [GalleryHistoryEntry]
    @Shared(.sxjBlockRules) private var rules: [SXJBlockRule]
    @Shared(.quickSearchWords) private var searches: [QuickSearchWord]
    @State private var reader = SXJAndroidBackupReader()
    @State private var plan: SXJAndroidBackupPlan?
    @State private var picking = false
    @State private var confirming = false
    @State private var busy = false
    @State private var status: String?

    var body: some View {
        Form {
            Section("选择 Android 导出") {
                Button("选择原版导出的 .db 文件") { picking = true }
                    .disabled(busy)
                    .fileImporter(isPresented: $picking, allowedContentTypes: [.data]) { result in
                        load(result)
                    }
                Text("在 Android 原版的数据管理中导出数据库，使用“文件”或隔空投送传到 iPhone。解析仅在本机进行。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let plan {
                Section("已解析，尚未修改当前数据") {
                    LabeledContent("本地收藏", value: plan.favorites.count.formatted())
                    LabeledContent("历史与阅读书签", value: plan.history.count.formatted())
                    LabeledContent("屏蔽规则", value: plan.rules.count.formatted())
                    LabeledContent("快速搜索", value: plan.searches.count.formatted())
                    LabeledContent("原版下载记录", value: plan.downloadRecords.formatted())
                    if plan.hasAdvancedSearches {
                        Text("快速搜索迁移名称和关键词。原版高级筛选参数尚未映射，请在迁移后重新设置筛选。")
                    }
                    Text("下载图片需另外使用“本地画廊导入”选择原下载目录。数据库中的下载任务不会自动成为已下载图片。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Button("合并导入已解析的数据") { confirming = true }
                    .disabled(plan == nil || busy)
                    .confirmationDialog("将合并收藏、历史、屏蔽和快速搜索；相同记录保留当前数据。", isPresented: $confirming) {
                        Button("合并导入") { apply() }
                        Button("取消", role: .cancel) {}
                    }
                Text("收藏、历史、快速搜索各最多保留 1,000 条，屏蔽最多 2,000 条。达到上限后保留已有数据。登录凭据不迁移。")
                    .font(.footnote).foregroundStyle(.secondary)
                if busy { ProgressView() }
                if let status { Text(status).textSelection(.enabled) }
            }
        }
        .navigationTitle("Android 数据迁移")
    }

    private func load(_ result: Result<URL, Error>) {
        plan = nil
        do {
            let url = try result.get()
            let host = setting.galleryHost
            busy = true
            Task {
                defer { busy = false }
                do {
                    plan = try await reader.read(url, host: host)
                    status = "已完成只读校验。请查看记录数量和迁移范围，再选择是否合并。"
                } catch { status = error.localizedDescription }
            }
        } catch { status = error.localizedDescription }
    }

    private func apply() {
        guard let plan else { return }
        $favorites.withLock { values in
            var ids = Set(values.map(\.gid))
            for gallery in plan.favorites where values.count < 1_000 {
                if ids.insert(gallery.gid).inserted { values.append(gallery) }
            }
        }
        $history.withLock { values in
            var ids = Set(values.map(\.gid))
            for entry in plan.history where values.count < GalleryHistoryEntry.historyCap {
                if ids.insert(entry.gid).inserted { values.append(entry) }
            }
            values.sort { $0.lastOpenDate > $1.lastOpenDate }
        }
        $rules.withLock { values in
            for rule in plan.rules where values.count < 2_000 {
                guard !values.contains(where: { $0.kind == rule.kind && $0.value == rule.value }) else { continue }
                values.append(rule)
            }
        }
        $searches.withLock { values in
            for search in plan.searches where values.count < 1_000 {
                let exists = values.contains { $0.name == search.name && $0.content == search.content }
                guard !exists else { continue }
                values.append(search)
            }
        }
        self.plan = nil
        status = "迁移已完成。请检查本地收藏、历史、屏蔽规则和快速搜索；下载图片可继续从原目录导入。"
    }
}
