import Foundation

extension FileManager {
    /// Returns the application support directory, creating it if needed.
    var applicationSupportDirectory: URL {
        let urls = self.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let url = urls.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? self.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
