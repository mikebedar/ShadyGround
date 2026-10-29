import Foundation

/// Where the grass harnesses read reference images and write their renders.
///
/// Set `SHADYGROUND_HARNESS_DIR` to a folder holding `ref/` (reference photos such as
/// `ball.jpg`) to compare against them; renders go to `out/` and `instanced/` beside it.
/// Without it everything goes to a folder under the temporary directory, and tests that
/// need a reference input are skipped.
enum HarnessPaths {
    static let root: String = {
        if let dir = ProcessInfo.processInfo.environment["SHADYGROUND_HARNESS_DIR"], !dir.isEmpty { return dir }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("ShadyGroundHarness", isDirectory: true).path
    }()

    /// `root/<name>`, created if missing.
    static func directory(_ name: String) -> String {
        let path = "\(root)/\(name)"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    /// Whether `ref/<name>` exists.
    static func hasReference(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: "\(root)/ref/\(name)")
    }
}
