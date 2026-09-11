import Foundation

public enum PathHistoryManager {

    public static func navigate(to newPath: URL, from currentPath: URL, history: PanelPathHistory) -> PanelPathHistory {
        var past = history.past
        past.append(currentPath)
        return PanelPathHistory(past: past, future: [])
    }

    public static func back(from currentPath: URL, history: PanelPathHistory) -> (path: URL, history: PanelPathHistory)? {
        guard let previousPath = history.past.last else { return nil }

        var past = history.past
        past.removeLast()
        let future = [currentPath] + history.future
        return (previousPath, PanelPathHistory(past: past, future: future))
    }

    public static func forward(from currentPath: URL, history: PanelPathHistory) -> (path: URL, history: PanelPathHistory)? {
        guard let nextPath = history.future.first else { return nil }

        var future = history.future
        future.removeFirst()
        let past = history.past + [currentPath]
        return (nextPath, PanelPathHistory(past: past, future: future))
    }
}
