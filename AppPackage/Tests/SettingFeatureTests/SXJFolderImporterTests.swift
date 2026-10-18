import AppModels
import Foundation
import Testing
@testable import SettingFeature

struct SXJFolderImporterTests {
    @Test func emptyDirectoryDoesNotCreateDownloadedGallery() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("downloads")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let importer = SXJFolderImporter(destinationRoot: destination)
        await #expect(throws: SXJFolderImporter.ImportError.self) {
            try await importer.importFolder(source, host: .ehentai)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func invalidImageIsRejectedWithoutModifyingSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("downloads")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let bytes = Data("not an image".utf8)
        let file = source.appendingPathComponent("001.png")
        try bytes.write(to: file)
        let importer = SXJFolderImporter(destinationRoot: destination)
        await #expect(throws: SXJFolderImporter.ImportError.self) {
            try await importer.importFolder(source, host: .ehentai)
        }
        #expect(try Data(contentsOf: file) == bytes)
        let imported = destination.appendingPathComponent("Imported")
        let remaining = try FileManager.default.contentsOfDirectory(atPath: imported.path)
        #expect(remaining.isEmpty)
    }

    @Test func validImagesCreateCompleteOfflineGalleryWithoutChangingSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("downloads")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let encoded = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
        let bytes = try #require(Data(base64Encoded: encoded))
        for name in ["001.png", "002.png"] { try bytes.write(to: source.appendingPathComponent(name)) }
        let importer = SXJFolderImporter(destinationRoot: destination)
        let count = try await importer.importFolder(source, host: .ehentai)
        #expect(count == 1)
        let folders = try FileManager.default.contentsOfDirectory(
            at: destination.appendingPathComponent("Imported"), includingPropertiesForKeys: nil
        )
        let folder = try #require(folders.first)
        #expect(folders.count == 1)
        let manifestData = try Data(contentsOf: folder.appendingPathComponent("manifest.json"))
        let manifest = try JSONDecoder().decode(DownloadManifest.self, from: manifestData)
        #expect(manifest.isComplete)
        #expect(manifest.pageCount == 2)
        let images = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "png" }
        #expect(images.count == 3)
        for image in images { #expect(try Data(contentsOf: image) == bytes) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: source.path).count == 2)
    }

    @Test func androidFolderPreservesIdentityAndMissingPagesAndSkipsDuplicateImport() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("downloads")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let encoded = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
        let bytes = try #require(Data(base64Encoded: encoded))
        for name in ["00000001.png", "00000003.png"] { try bytes.write(to: source.appendingPathComponent(name)) }
        let header = "VERSION2\n00000000\n12345\nabcdef1234\n1\n1\n40\n3\n"
        try Data(header.utf8).write(to: source.appendingPathComponent(".ehviewer"))
        let importer = SXJFolderImporter(destinationRoot: destination)
        #expect(try await importer.importFolder(source, host: .ehentai) == 1)
        let folders = try FileManager.default.contentsOfDirectory(
            at: destination.appendingPathComponent("Imported"), includingPropertiesForKeys: nil
        )
        let folder = try #require(folders.first)
        let manifest = try JSONDecoder().decode(
            DownloadManifest.self, from: Data(contentsOf: folder.appendingPathComponent("manifest.json"))
        )
        #expect(manifest.gid == "12345")
        #expect(manifest.token == "abcdef1234")
        #expect(manifest.pageCount == 3)
        #expect(manifest.completedPageCount == 2)
        #expect(manifest.pages[2] == "")
        #expect(try await importer.importFolder(source, host: .ehentai) == 0)
        #expect(try Data(contentsOf: source.appendingPathComponent("00000001.png")) == bytes)
    }

}
