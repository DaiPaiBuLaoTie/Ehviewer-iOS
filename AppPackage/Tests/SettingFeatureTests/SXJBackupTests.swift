import AppModels
import Foundation
import Testing
@testable import SettingFeature

struct SXJBackupTests {
    private func backup() -> SXJBackup {
        SXJBackup(
            setting: Setting(), searchFilter: Filter(), globalFilter: Filter(), watchedFilter: Filter(),
            historyKeywords: ["sample"], quickSearchWords: [.init(name: "Sample", content: "language:english")],
            galleryHistory: [.init(gid: "123", token: "token", lastOpenDate: Date(), readingProgress: 5)],
            blockRules: [.init(kind: .uploader, value: "Example")], localFavorites: nil
        )
    }

    @Test func roundTripPreservesSearchHistoryAndProgress() throws {
        let restored = try SXJBackup.decode(backup().encoded())
        #expect(restored.historyKeywords == ["sample"])
        #expect(restored.galleryHistory.first?.readingProgress == 5)
        #expect(restored.blockRules.first?.value == "Example")
        #expect(restored.quickSearchWords.first?.content == "language:english")
    }

    @Test func rejectsFutureVersionBeforeRestore() throws {
        var source = backup()
        source.version = 999
        let data = try source.encoded()
        #expect(throws: SXJBackup.BackupError.self) { try SXJBackup.decode(data) }
    }

    @Test func rejectsDuplicateBlockIdentifiers() throws {
        var source = backup()
        if let first = source.blockRules.first { source.blockRules.append(first) }
        let data = try source.encoded()
        #expect(throws: SXJBackup.BackupError.self) { try SXJBackup.decode(data) }
    }

    @Test func excludesCredentialsFromExport() throws {
        let data = try backup().encoded()
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("ipb_pass_hash"))
        #expect(!text.contains("ipb_member_id"))
    }
}
