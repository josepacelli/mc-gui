import Foundation

/// Pure, stateless back/forward navigation over a panel's `PanelPathHistory` (in-memory
/// only; disk persistence is `PathHistoryStore`/`PathHistoryStoreImpl`).
///
/// Mirrors standard browser history semantics: navigating to a new path pushes the
/// previous path onto `past` and discards any `future` (forward) entries, since they no
/// longer follow from the new current path.
public enum PathHistoryManager {

    /// Records a navigation from `currentPath` to `newPath`: pushes `currentPath` onto
    /// `past` and clears `future` (a fresh navigation invalidates the old forward stack).
    public static func navigate(to newPath: URL, from currentPath: URL, history: PanelPathHistory) -> PanelPathHistory {
        var past = history.past
        past.append(currentPath)
        return PanelPathHistory(past: past, future: [])
    }

    /// Moves back one step: pops the most recent entry off `past`, pushes `currentPath`
    /// onto the front of `future`, and returns the path to navigate to. Returns `nil`
    /// when `past` is empty (no history to go back to).
    public static func back(from currentPath: URL, history: PanelPathHistory) -> (path: URL, history: PanelPathHistory)? {
        guard let previousPath = history.past.last else { return nil }

        var past = history.past
        past.removeLast()
        let future = [currentPath] + history.future
        return (previousPath, PanelPathHistory(past: past, future: future))
    }

    /// Moves forward one step: pops the next entry off `future`, pushes `currentPath`
    /// onto `past`, and returns the path to navigate to. Returns `nil` when `future` is
    /// empty (no forward history).
    public static func forward(from currentPath: URL, history: PanelPathHistory) -> (path: URL, history: PanelPathHistory)? {
        guard let nextPath = history.future.first else { return nil }

        var future = history.future
        future.removeFirst()
        let past = history.past + [currentPath]
        return (nextPath, PanelPathHistory(past: past, future: future))
    }
}
