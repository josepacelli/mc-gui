import Foundation
import MCGuiCore
import MCGuiUI

/// Persists last-used panel directories, per-panel sort/hidden-files preference, and
/// which panel was active, across launches - via plain `UserDefaults` (small scalar
/// values, no need for the `BookmarkStore`/`UserMenuStore` JSON-file pattern used
/// elsewhere for arrays of user-authored records). Window geometry itself is handled
/// separately by `NSWindow.setFrameAutosaveName` (`WindowManager.showMainWindow`), which
/// already persists position/size natively - no custom code needed for that part.
enum AppSettingsStore {
    private static let defaults = UserDefaults.standard

    private enum Key: String {
        case leftPath = "AppSettings.leftPath"
        case rightPath = "AppSettings.rightPath"
        case leftSortColumn = "AppSettings.leftSortColumn"
        case rightSortColumn = "AppSettings.rightSortColumn"
        case leftShowHidden = "AppSettings.leftShowHidden"
        case rightShowHidden = "AppSettings.rightShowHidden"
        case activePanel = "AppSettings.activePanel"
    }

    struct Snapshot {
        var leftPath: URL
        var rightPath: URL
        var leftSortColumn: PanelSortColumn
        var rightSortColumn: PanelSortColumn
        var leftShowHidden: Bool
        var rightShowHidden: Bool
        var activePanel: PanelSide
    }

    /// Loads the last-saved snapshot, falling back to the home directory / defaults for
    /// anything missing or no longer valid (e.g. a saved path on an unmounted volume).
    static func load() -> Snapshot {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return Snapshot(
            leftPath: validDirectory(defaults.string(forKey: Key.leftPath.rawValue)) ?? home,
            rightPath: validDirectory(defaults.string(forKey: Key.rightPath.rawValue)) ?? home,
            leftSortColumn: sortColumn(defaults.string(forKey: Key.leftSortColumn.rawValue)),
            rightSortColumn: sortColumn(defaults.string(forKey: Key.rightSortColumn.rawValue)),
            leftShowHidden: defaults.bool(forKey: Key.leftShowHidden.rawValue),
            rightShowHidden: defaults.bool(forKey: Key.rightShowHidden.rawValue),
            activePanel: defaults.string(forKey: Key.activePanel.rawValue) == PanelSide.right.rawValue ? .right : .left
        )
    }

    /// Saves the current state - called on quit (`applicationWillTerminate`).
    @MainActor
    static func save(_ viewModel: MainWindowViewModel) {
        defaults.set(viewModel.leftPanel.currentPath.path, forKey: Key.leftPath.rawValue)
        defaults.set(viewModel.rightPanel.currentPath.path, forKey: Key.rightPath.rawValue)
        defaults.set(viewModel.leftPanel.sortColumn.rawValue, forKey: Key.leftSortColumn.rawValue)
        defaults.set(viewModel.rightPanel.sortColumn.rawValue, forKey: Key.rightSortColumn.rawValue)
        defaults.set(viewModel.leftPanel.showHidden, forKey: Key.leftShowHidden.rawValue)
        defaults.set(viewModel.rightPanel.showHidden, forKey: Key.rightShowHidden.rawValue)
        defaults.set(viewModel.activePanel.rawValue, forKey: Key.activePanel.rawValue)
    }

    private static func validDirectory(_ path: String?) -> URL? {
        guard let path else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
        return URL(fileURLWithPath: path)
    }

    private static func sortColumn(_ raw: String?) -> PanelSortColumn {
        raw.flatMap(PanelSortColumn.init(rawValue:)) ?? .name
    }
}
