
import Foundation

/// Internal manager for handling file storage
internal class StorageManager {
    
    static let shared = StorageManager()
    
    private let fileManager = FileManager.default
    private let miniappsDirectoryName = "miniapps"
    
    private init() {}
    
    /// Get the Documents directory path
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Get the miniapps directory path
    var miniappsDirectory: URL {
        documentsDirectory.appendingPathComponent(miniappsDirectoryName)
    }
    
    /// Get ZIP file path for a mini app
    func zipPath(for appId: String) -> URL {
        miniappsDirectory.appendingPathComponent("\(appId).zip")
    }
    
    /// Get extracted folder path for a mini app
    func extractedPath(for appId: String) -> URL {
        miniappsDirectory.appendingPathComponent(appId)
    }
    
    /// Get index.html path for a mini app
    /// Checks root, app/ folder, and recursively searches subdirectories
    func indexPath(for appId: String) -> URL? {
        let extractedPath = self.extractedPath(for: appId)
        
        print("MiniAppsSDK: ========== Searching for index.html ==========")
        print("MiniAppsSDK: Search base path: \(extractedPath.path)")
        
        // Verify base directory exists
        guard fileManager.fileExists(atPath: extractedPath.path) else {
            print("MiniAppsSDK: ✗ ERROR: Extraction directory does not exist: \(extractedPath.path)")
            return nil
        }
        
        // Check root first
        let rootIndexPath = extractedPath.appendingPathComponent("index.html")
        let rootExists = fileManager.fileExists(atPath: rootIndexPath.path)
        print("MiniAppsSDK: Checking root: \(rootIndexPath.path) - \(rootExists ? "EXISTS" : "NOT FOUND")")
        if rootExists {
            print("MiniAppsSDK: ✓ Found index.html at root: \(rootIndexPath.path)")
            return rootIndexPath
        }
        
        // Check app/ folder
        let appFolderPath = extractedPath.appendingPathComponent("app")
        let appFolderExists = fileManager.fileExists(atPath: appFolderPath.path)
        print("MiniAppsSDK: Checking app folder: \(appFolderPath.path) - \(appFolderExists ? "EXISTS" : "NOT FOUND")")
        
        if appFolderExists {
            let appIndexPath = appFolderPath.appendingPathComponent("index.html")
            let appIndexExists = fileManager.fileExists(atPath: appIndexPath.path)
            print("MiniAppsSDK: Checking app/index.html: \(appIndexPath.path) - \(appIndexExists ? "EXISTS" : "NOT FOUND")")
            if appIndexExists {
                print("MiniAppsSDK: ✓ Found index.html in app/ folder: \(appIndexPath.path)")
                return appIndexPath
            }
        }
        
        // Recursively search all subdirectories
        print("MiniAppsSDK: Searching recursively...")
        if let enumerator = fileManager.enumerator(at: extractedPath, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            var foundCount = 0
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent == "index.html" {
                    foundCount += 1
                    let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let exists = fileManager.fileExists(atPath: fileURL.path)
                    print("MiniAppsSDK: Found potential index.html: \(fileURL.path) - isDir: \(isDir), exists: \(exists)")
                    if !isDir && exists {
                        print("MiniAppsSDK: ✓ Found index.html recursively: \(fileURL.path)")
                        return fileURL
                    }
                }
            }
            print("MiniAppsSDK: Recursive search found \(foundCount) potential index.html files")
        }
        
        // Log directory structure for debugging
        print("MiniAppsSDK: ✗ index.html not found. Full directory structure:")
        self.logFullDirectoryStructure(at: extractedPath, indent: "")
        
        return nil
    }
    
    /// Recursively log full directory structure
    private func logFullDirectoryStructure(at directory: URL, indent: String) {
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: []) else {
            print("\(indent)MiniAppsSDK: [Could not read directory: \(directory.path)]")
            return
        }
        
        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let exists = fileManager.fileExists(atPath: item.path)
            let size: String
            if isDir {
                size = ""
            } else {
                let fileSize = (try? fileManager.attributesOfItem(atPath: item.path)[.size] as? Int64) ?? 0
                size = " (\(fileSize) bytes)"
            }
            print("\(indent)MiniAppsSDK:   - \(item.lastPathComponent)\(isDir ? " (directory)" : " (file)\(size)") - exists: \(exists)")
            
            // Recursively log subdirectories (limit depth)
            if isDir && indent.count < 12 {
                logFullDirectoryStructure(at: item, indent: indent + "    ")
            }
        }
    }
    
    /// Get the base directory for loading the mini app (for allowingReadAccessTo)
    func basePath(for appId: String) -> URL {
        extractedPath(for: appId)
    }
    
    /// Ensure miniapps directory exists
    func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: miniappsDirectory.path) {
            try fileManager.createDirectory(at: miniappsDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Check if ZIP file exists
    func zipExists(for appId: String) -> Bool {
        fileManager.fileExists(atPath: zipPath(for: appId).path)
    }
    
    /// Check if extracted folder exists
    func extractedExists(for appId: String) -> Bool {
        fileManager.fileExists(atPath: extractedPath(for: appId).path)
    }
    
    /// Check if index.html exists (in root or app/ folder)
    func indexExists(for appId: String) -> Bool {
        indexPath(for: appId) != nil
    }
}
