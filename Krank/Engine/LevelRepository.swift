import Foundation

enum LevelRepositoryError: LocalizedError {
    case missingLevelFiles
    case decodeFailed(URL)

    var errorDescription: String? {
        switch self {
        case .missingLevelFiles:
            return "No level files were found in the app bundle."
        case .decodeFailed(let url):
            return "Could not decode level JSON: \(url.lastPathComponent)"
        }
    }
}

final class LevelRepository {
    private let decoder = JSONDecoder()

    func loadLevels(bundle: Bundle = .main) throws -> [Level] {
        if let catalogURL = findCatalogURL(bundle: bundle) {
            return try decodeCatalog(at: catalogURL)
        }

        let levelURLs = findLevelURLs(bundle: bundle)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !levelURLs.isEmpty else {
            throw LevelRepositoryError.missingLevelFiles
        }

        return try levelURLs.map { url in
            do {
                let data = try Data(contentsOf: url)
                return try decoder.decode(Level.self, from: data)
            } catch {
                throw LevelRepositoryError.decodeFailed(url)
            }
        }
    }

    private func decodeCatalog(at url: URL) throws -> [Level] {
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([Level].self, from: data)
        } catch {
            throw LevelRepositoryError.decodeFailed(url)
        }
    }

    private func findCatalogURL(bundle: Bundle) -> URL? {
        if let url = bundle.url(forResource: "levels_catalog", withExtension: "json", subdirectory: "Levels") {
            return url
        }

        if let url = bundle.url(forResource: "levels_catalog", withExtension: "json") {
            return url
        }

        return recursiveJSONURLs(bundle: bundle).first { $0.lastPathComponent == "levels_catalog.json" }
    }

    private func findLevelURLs(bundle: Bundle) -> [URL] {
        var candidates: [URL] = []

        if let levelFolderURLs = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Levels") {
            candidates.append(contentsOf: levelFolderURLs)
        }

        if let rootURLs = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            candidates.append(contentsOf: rootURLs)
        }

        candidates.append(contentsOf: recursiveJSONURLs(bundle: bundle))

        var deduped: [URL] = []
        var seenPaths = Set<String>()

        for url in candidates {
            let key = url.standardizedFileURL.path
            if seenPaths.insert(key).inserted {
                deduped.append(url)
            }
        }

        return deduped.filter { $0.lastPathComponent.hasPrefix("lvl_") }
    }

    private func recursiveJSONURLs(bundle: Bundle) -> [URL] {
        guard let resourceURL = bundle.resourceURL else {
            return []
        }

        guard let enumerator = FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "json" {
            urls.append(url)
        }
        return urls
    }
}
