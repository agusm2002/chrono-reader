import Foundation

struct ComicReaderSettings: Codable, Equatable {
    var readingModeRawValue: String
    var doublePaged: Bool
    var isolateFirstPage: Bool
    var useWhiteBackground: Bool
    var showThumbnails: Bool

    static let `default` = ComicReaderSettings(
        readingModeRawValue: "Cómic (LTR)",
        doublePaged: false,
        isolateFirstPage: true,
        useWhiteBackground: false,
        showThumbnails: true
    )
}

enum ComicReaderDefaultsStorage {
    static let readingModeKey = "defaultComicReadingMode"
    static let doublePagedKey = "defaultComicDoublePaged"
    static let isolateFirstPageKey = "defaultComicIsolateFirstPage"
    static let useWhiteBackgroundKey = "defaultComicUseWhiteBackground"
    static let showThumbnailsKey = "defaultComicShowThumbnails"

    static func load(from userDefaults: UserDefaults = .standard) -> ComicReaderSettings {
        let fallback = ComicReaderSettings.default

        return ComicReaderSettings(
            readingModeRawValue: userDefaults.string(forKey: readingModeKey) ?? fallback.readingModeRawValue,
            doublePaged: userDefaults.object(forKey: doublePagedKey) as? Bool ?? fallback.doublePaged,
            isolateFirstPage: userDefaults.object(forKey: isolateFirstPageKey) as? Bool ?? fallback.isolateFirstPage,
            useWhiteBackground: userDefaults.object(forKey: useWhiteBackgroundKey) as? Bool ?? fallback.useWhiteBackground,
            showThumbnails: userDefaults.object(forKey: showThumbnailsKey) as? Bool ?? fallback.showThumbnails
        )
    }
}
