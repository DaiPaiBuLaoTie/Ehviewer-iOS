import AppModels
import AppTools
import DownloadClient
import Foundation
import ImageIO

/// Imports user-selected image folders without modifying the original files.
actor SXJFolderImporter {
    private let destinationRoot: URL

    init(destinationRoot: URL = FileUtil.downloadsDirectoryURL) {
        self.destinationRoot = destinationRoot
    }

    private let extensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "avif", "heic", "apng", "bmp"]

    func importFolder(_ source: URL, host: GalleryHost) throws -> Int {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let manager = FileManager()
        let root = source.resolvingSymlinksInPath().standardizedFileURL
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let enumerator = manager.enumerator(
            at: root, includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles]
        ) else { throw CocoaError(.fileReadNoPermission) }
        var groups: [URL: [URL]] = [:]
        var bytes = 0
        var pages = 0
        for case let file as URL in enumerator {
            try Task.checkCancellation()
            let values = try file.resourceValues(forKeys: resourceKeys)
            guard values.isSymbolicLink != true, values.isRegularFile == true,
                  extensions.contains(file.pathExtension.lowercased()),
                  file.resolvingSymlinksInPath().path.hasPrefix(root.path + "/")
            else { continue }
            bytes += values.fileSize ?? 0
            pages += 1
            guard pages <= 20_000, bytes <= 16 * 1_024 * 1_024 * 1_024,
                  (values.fileSize ?? 0) <= 256 * 1_024 * 1_024
            else { throw ImportError.limitExceeded }
            var folder = file.deletingLastPathComponent()
            if folder.lastPathComponent.lowercased() == "pages" { folder.deleteLastPathComponent() }
            groups[folder, default: []].append(file)
        }
        guard !groups.isEmpty else { throw ImportError.noImages }
        var imported = 0
        for (folder, files) in groups.sorted(by: { $0.key.path < $1.key.path }) {
            try Task.checkCancellation()
            try importBook(folder: folder, images: files, host: host, manager: manager)
            imported += 1
        }
        return imported
    }

    private func importBook(folder: URL, images: [URL], host: GalleryHost, manager: FileManager) throws {
        let storage = DownloadStore(rootURL: destinationRoot)
        try storage.ensureRootDirectory()
        let parent = storage.userFolderURL(name: "Imported")
        try manager.createDirectory(at: parent, withIntermediateDirectories: true)
        let identity = "local-" + UUID().uuidString.lowercased()
        let token = "local"
        let name = storage.makeFolderRelativePath(gid: identity, token: token, title: folder.lastPathComponent)
        let destination = parent.appendingPathComponent(name, isDirectory: true)
        let staging = parent.appendingPathComponent(".import-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            var hashes: [Int: String] = [:]
            let sorted = images.sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
            for (offset, source) in sorted.enumerated() {
                try Task.checkCancellation()
                let index = offset + 1
                let relative = storage.makePageRelativePath(
                    gid: identity, token: token, index: index, fileExtension: source.pathExtension.lowercased()
                )
                let target = staging.appendingPathComponent(relative)
                try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                var failure: Error?
                var coordinationError: NSError?
                NSFileCoordinator().coordinate(readingItemAt: source, error: &coordinationError) { localURL in
                    do { try manager.copyItem(at: localURL, to: target) } catch { failure = error }
                }
                if let coordinationError { throw coordinationError }
                if let failure { throw failure }
                guard CGImageSourceCreateWithURL(target as CFURL, nil) != nil else { throw ImportError.invalidImage }
                hashes[index] = try storage.fileHash(at: target)
                if index == 1 {
                    let cover = storage.makeCoverRelativePath(
                        gid: identity, token: token, fileExtension: source.pathExtension.lowercased()
                    )
                    try manager.copyItem(at: target, to: staging.appendingPathComponent(cover))
                }
            }
            let manifest = DownloadManifest(
                gid: identity, host: host, token: token, title: folder.lastPathComponent,
                jpnTitle: nil, category: .misc, language: .other, remoteCoverURL: nil,
                uploader: nil, tags: [], postedDate: Date(), rating: 0, pages: hashes
            )
            try storage.writeManifest(manifest, folderURL: staging)
            try manager.moveItem(at: staging, to: destination)
        } catch {
            try? manager.removeItem(at: staging)
            throw error
        }
    }

    enum ImportError: LocalizedError {
        case noImages
        case invalidImage
        case limitExceeded

        var errorDescription: String? {
            switch self {
            case .noImages: return "所选目录没有支持的图片。请先解压压缩包，再选择图片目录。"
            case .invalidImage: return "目录中存在无法识别的图片，本画廊未写入下载库。"
            case .limitExceeded: return "单次导入上限为 20,000 页、16 GB，单张图片最多 256 MB。请分批导入。"
            }
        }
    }
}
