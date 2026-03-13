
import Foundation
import ZIPFoundation
import os.log

/// Internal manager for downloading and extracting mini app ZIP files
internal class DownloadManager {
    
    // Logging function to avoid conflicts with instance methods named 'print'
    // Uses multiple methods to ensure visibility
    private static let logger = OSLog(subsystem: "com.miniapps.sdk", category: "DownloadManager")
    
    private func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        let message = items.map { "\($0)" }.joined(separator: separator)
        let fullMessage = message + (terminator == "\n" ? "" : terminator)
        
        // Method 1: Use os_log (most reliable for Xcode console)
        os_log("%{public}@", log: DownloadManager.logger, type: .default, fullMessage)
        
        // Method 2: Use NSLog (backup)
        NSLog("%@", fullMessage)
        
        // Method 3: Write directly to stderr (always visible)
        fullMessage.withCString { cString in
            fputs(cString, stderr)
            if terminator == "\n" {
                fputs("\n", stderr)
            }
            fflush(stderr)
        }
    }
    
    static let shared = DownloadManager()
    
    private let storageManager = StorageManager.shared
    private let metricsReporter = MetricsReporter.shared
    
    private init() {}
    
    /// Download and extract mini app
    func downloadAndExtract(
        appId: String,
        downloadURL: URL,
        checksum: String,
        version: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Report download initiated
        metricsReporter.reportEvent(
            appId: appId,
            version: version,
            eventType: "ZipDownloadInitiated",
            message: nil,
            metadata: nil
        )
        
        // Ensure directory exists
        do {
            try storageManager.ensureDirectoryExists()
        } catch {
            completion(.failure(error))
            return
        }
        
        let zipPath = storageManager.zipPath(for: appId)
        
        // Download ZIP file with checksum
        downloadFile(from: downloadURL, to: zipPath, checksum: checksum) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                // Report download completed
                self.metricsReporter.reportEvent(
                    appId: appId,
                    version: version,
                    eventType: "ZipDownloadCompleted",
                    message: nil,
                    metadata: self.getFileSizeMetadata(for: zipPath)
                )
                
                // Extract ZIP
                self.extractZip(at: zipPath, appId: appId, version: version, completion: completion)
                
            case .failure(let error):
                // Report download failed
                self.metricsReporter.reportEvent(
                    appId: appId,
                    version: version,
                    eventType: "ZipDownloadFailed",
                    message: error.localizedDescription,
                    metadata: nil
                )
                completion(.failure(error))
            }
        }
    }
    
    private func downloadFile(from url: URL, to destination: URL, checksum: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Ensure destination directory exists
        let destinationDir = destination.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Create URLRequest with proper configuration
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60.0
        
        URLSession.shared.downloadTask(with: request) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            
            // Handle network errors
            if let error = error {
                self.log("MiniAppsSDK: Download error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Check HTTP response status
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    let error = NSError(
                        domain: "DownloadManager",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"]
                    )
                    completion(.failure(error))
                    return
                }
            }
            
            // Verify temporary file exists
            guard let tempURL = tempURL else {
                let error = NSError(
                    domain: "DownloadManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No temporary file URL received"]
                )
                completion(.failure(error))
                return
            }
            
            // Verify temporary file exists and has content
            guard FileManager.default.fileExists(atPath: tempURL.path) else {
                let error = NSError(
                    domain: "DownloadManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Temporary file does not exist"]
                )
                completion(.failure(error))
                return
            }
            
            // Check file size
            if let attributes = try? FileManager.default.attributesOfItem(atPath: tempURL.path),
               let fileSize = attributes[.size] as? Int64 {
                if fileSize == 0 {
                    let error = NSError(
                        domain: "DownloadManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Downloaded file is empty"]
                    )
                    completion(.failure(error))
                    return
                }
            }
            
            do {
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                
                // Move file from temporary location to destination
                try FileManager.default.moveItem(at: tempURL, to: destination)
                
                // Verify file was moved successfully
                guard FileManager.default.fileExists(atPath: destination.path) else {
                    let error = NSError(
                        domain: "DownloadManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "File was not moved successfully"]
                    )
                    completion(.failure(error))
                    return
                }
                
                // Validate checksum length (should be 200 hex characters for 100 bytes)
                guard checksum.count == 200 else {
                    let error = NSError(
                        domain: "DownloadManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid checksum length: expected 200 hex characters (100 bytes), got \(checksum.count)"]
                    )
                    completion(.failure(error))
                    return
                }
                
                // Convert hex string to Data (100 bytes = 200 hex characters)
                guard let checksumData = self.hexStringToData(checksum) else {
                    let error = NSError(
                        domain: "DownloadManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid checksum format"]
                    )
                    completion(.failure(error))
                    return
                }
                
                // Verify checksum data length is exactly 100 bytes
                guard checksumData.count == 100 else {
                    let error = NSError(
                        domain: "DownloadManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid checksum data length: expected 100 bytes, got \(checksumData.count)"]
                    )
                    completion(.failure(error))
                    return
                }
                
                // Append checksum to file
                let fileHandle = try FileHandle(forWritingTo: destination)
                fileHandle.seekToEndOfFile()
                fileHandle.write(checksumData)
                try fileHandle.synchronize()
                try fileHandle.close()
                
                completion(.success(()))
            } catch {
                let error = NSError(
                    domain: "DownloadManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to process downloaded file: \(error.localizedDescription)"]
                )
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Convert hex string to Data
    /// - Parameter hexString: Hex string (e.g., "031400080008008cad6a5c...")
    /// - Returns: Data representation of hex string, or nil if invalid
    private func hexStringToData(_ hexString: String) -> Data? {
        let hex = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // Validate hex string length (should be even, 200 chars for 100 bytes)
        guard hex.count % 2 == 0 else {
            return nil
        }
        
        let expectedBytes = hex.count / 2
        var data = Data(capacity: expectedBytes)
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard nextIndex <= hex.endIndex else {
                break
            }
            
            let byteString = hex[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        
        // Verify we got the expected number of bytes
        guard data.count == expectedBytes else {
            return nil
        }
        
        return data
    }
    
    private func extractZip(at zipPath: URL, appId: String, version: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let extractPath = storageManager.extractedPath(for: appId)
        
        // Verify ZIP file exists before attempting extraction
        guard FileManager.default.fileExists(atPath: zipPath.path) else {
            let error = NSError(
                domain: "DownloadManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "ZIP file not found at path: \(zipPath.path)"]
            )
            metricsReporter.reportEvent(
                appId: appId,
                version: version,
                eventType: "ZipExtractFailed",
                message: "ZIP file not found",
                metadata: nil
            )
            completion(.failure(error))
            return
        }
        
        // Check ZIP file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: zipPath.path),
           let fileSize = attributes[.size] as? Int64 {
            if fileSize == 0 {
                let error = NSError(
                    domain: "DownloadManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "ZIP file is empty"]
                )
                metricsReporter.reportEvent(
                    appId: appId,
                    version: version,
                    eventType: "ZipExtractFailed",
                    message: "ZIP file is empty",
                    metadata: nil
                )
                completion(.failure(error))
                return
            }
        }
        
        // Remove existing extraction if present
        if FileManager.default.fileExists(atPath: extractPath.path) {
            try? FileManager.default.removeItem(at: extractPath)
        }
        
        // Create extraction directory
        do {
            try FileManager.default.createDirectory(at: extractPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            metricsReporter.reportEvent(
                appId: appId,
                version: version,
                eventType: "ZipExtractFailed",
                message: "Failed to create extraction directory: \(error.localizedDescription)",
                metadata: nil
            )
            completion(.failure(error))
            return
        }
        
        // Extract ZIP using ZIPFoundation
        extractZipFile(at: zipPath, to: extractPath, appId: appId, version: version, completion: completion)
    }
    
    private func extractZipFile(at zipPath: URL, to destination: URL, appId: String, version: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Extract ZIP using ZIPFoundation
        // Verify ZIP file exists
        guard FileManager.default.fileExists(atPath: zipPath.path) else {
            let error = NSError(
                domain: "DownloadManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "ZIP file not found at path: \(zipPath.path)"]
            )
            metricsReporter.reportEvent(
                appId: appId,
                version: version,
                eventType: "ZipExtractFailed",
                message: "ZIP file not found",
                metadata: nil
            )
            completion(.failure(error))
            return
        }
        
        // Ensure destination directory exists
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
        } catch {
            metricsReporter.reportEvent(
                appId: appId,
                version: version,
                eventType: "ZipExtractFailed",
                message: "Failed to create destination directory: \(error.localizedDescription)",
                metadata: nil
            )
            completion(.failure(error))
            return
        }
        
        // Extract ZIP using ZIPFoundation
        // Perform extraction on background queue to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            
            // Verify ZIP file exists
            guard fileManager.fileExists(atPath: zipPath.path) else {
                DispatchQueue.main.async {
                    let error = NSError(
                        domain: "DownloadManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "ZIP file not found at path: \(zipPath.path)"]
                    )
                    completion(.failure(error))
                }
                return
            }
            
            // Ensure destination directory is empty (ZIPFoundation requires empty destination)
            if fileManager.fileExists(atPath: destination.path) {
                if let contents = try? fileManager.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil, options: []), !contents.isEmpty {
                    do {
                        try fileManager.removeItem(at: destination)
                    } catch {
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                        return
                    }
                }
            }
            
            // Create destination directory (will be empty now)
            if !fileManager.fileExists(atPath: destination.path) {
                do {
                    try fileManager.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
            }
            
            // ZIPFoundation requires absolute URLs
            let absoluteZipURL = zipPath.absoluteURL
            let absoluteDestURL = destination.absoluteURL
            
            // Store temp ZIP URL for cleanup in error cases
            var finalTempZipURL: URL?
            
            do {
                // Verify URLs are file URLs
                guard absoluteZipURL.isFileURL && absoluteDestURL.isFileURL else {
                    throw NSError(
                        domain: "DownloadManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid file URLs for ZIP extraction"]
                    )
                }
                
                // Verify ZIP file is readable
                guard fileManager.isReadableFile(atPath: absoluteZipURL.path) else {
                    throw NSError(
                        domain: "DownloadManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "ZIP file is not readable"]
                    )
                }
                
                // Verify destination directory exists and is empty
                guard fileManager.fileExists(atPath: absoluteDestURL.path) else {
                    throw NSError(
                        domain: "DownloadManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Destination directory does not exist"]
                    )
                }
                
                // Check if destination is empty
                if let destContents = try? fileManager.contentsOfDirectory(at: absoluteDestURL, includingPropertiesForKeys: nil, options: []), !destContents.isEmpty {
                    throw NSError(
                        domain: "DownloadManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Destination directory is not empty (\(destContents.count) items)"]
                    )
                }
                
                // Read ZIP file with checksum
                guard let zipDataWithChecksum = try? Data(contentsOf: absoluteZipURL) else {
                    throw NSError(
                        domain: "DownloadManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to read ZIP file"]
                    )
                }
                
                // Find End of Central Directory (EOCD) record to determine actual ZIP size
                // EOCD signature is 0x06054b50 (bytes: 50 4B 05 06)
                // Search backwards from end (max comment length is 65535 + 22 bytes for EOCD = 65557)
                let maxSearch = min(65557, zipDataWithChecksum.count)
                var eocdOffset: Int? = nil
                
                // Search backwards for EOCD signature
                for i in stride(from: maxSearch, through: 22, by: -1) {
                    let searchPos = zipDataWithChecksum.count - i
                    if searchPos >= 0 && searchPos + 4 <= zipDataWithChecksum.count {
                        let bytes = zipDataWithChecksum[searchPos..<(searchPos + 4)]
                        if bytes[bytes.startIndex] == 0x50 &&
                           bytes[bytes.index(bytes.startIndex, offsetBy: 1)] == 0x4B &&
                           bytes[bytes.index(bytes.startIndex, offsetBy: 2)] == 0x05 &&
                           bytes[bytes.index(bytes.startIndex, offsetBy: 3)] == 0x06 {
                            eocdOffset = searchPos
                            self.log("MiniAppsSDK: Found EOCD signature at offset: \(searchPos)")
                            break
                        }
                    }
                }
                
                let zipDataForExtraction: Data
                if let eocdPos = eocdOffset, eocdPos + 22 <= zipDataWithChecksum.count {
                    // Read comment length from EOCD (offset 20 from EOCD start)
                    let commentLengthPos = eocdPos + 20
                    if commentLengthPos + 2 <= zipDataWithChecksum.count {
                        let commentLengthBytes = zipDataWithChecksum[commentLengthPos..<(commentLengthPos + 2)]
                        // Read UInt16 in little-endian format
                        let byte0 = UInt16(commentLengthBytes[commentLengthBytes.startIndex])
                        let byte1 = UInt16(commentLengthBytes[commentLengthBytes.index(commentLengthBytes.startIndex, offsetBy: 1)])
                        let commentLength = Int(byte0 | (byte1 << 8))
                        let actualZipEnd = eocdPos + 22 + commentLength
                        
                        self.log("MiniAppsSDK: EOCD found at: \(eocdPos)")
                        self.log("MiniAppsSDK: Comment length: \(commentLength)")
                        self.log("MiniAppsSDK: Actual ZIP end: \(actualZipEnd)")
                        self.log("MiniAppsSDK: File size: \(zipDataWithChecksum.count)")
                        self.log("MiniAppsSDK: Extra bytes: \(zipDataWithChecksum.count - actualZipEnd)")
                        
                        if actualZipEnd < zipDataWithChecksum.count {
                            // Strip extra bytes (checksum)
                            zipDataForExtraction = zipDataWithChecksum.prefix(actualZipEnd)
                            self.log("MiniAppsSDK: Stripped \(zipDataWithChecksum.count - actualZipEnd) bytes (checksum)")
                        } else {
                            // No extra bytes, use as-is
                            zipDataForExtraction = zipDataWithChecksum
                            self.log("MiniAppsSDK: No extra bytes found, using ZIP as-is")
                        }
                    } else {
                        // Can't read comment length, strip last 100 bytes
                        self.log("MiniAppsSDK: Cannot read comment length, using fallback (strip 100 bytes)")
                        guard zipDataWithChecksum.count >= 100 else {
                            throw NSError(domain: "DownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "ZIP file too small"])
                        }
                        zipDataForExtraction = zipDataWithChecksum.prefix(zipDataWithChecksum.count - 100)
                    }
                } else {
                    // EOCD not found, strip last 100 bytes as fallback
                    self.log("MiniAppsSDK: EOCD not found, using fallback (strip 100 bytes)")
                    guard zipDataWithChecksum.count >= 100 else {
                        throw NSError(domain: "DownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "ZIP file too small"])
                    }
                    zipDataForExtraction = zipDataWithChecksum.prefix(zipDataWithChecksum.count - 100)
                }
                
                self.log("MiniAppsSDK: ZIP data for extraction size: \(zipDataForExtraction.count) bytes")
                
                // Create temporary ZIP file without checksum for extraction
                let tempDir = absoluteZipURL.deletingLastPathComponent()
                let tempFileName = "temp_\(UUID().uuidString).zip"
                let tempZipURL = tempDir.appendingPathComponent(tempFileName)
                finalTempZipURL = URL(fileURLWithPath: tempZipURL.path)
                
                guard let tempURL = finalTempZipURL else {
                    throw NSError(domain: "DownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create temp ZIP URL"])
                }
                
                self.log("MiniAppsSDK: Creating temp ZIP file: \(tempURL.path)")
                
                // Write ZIP data without checksum
                try zipDataForExtraction.write(to: tempURL, options: .atomic)
                
                // Verify temp file was written
                guard fileManager.fileExists(atPath: tempURL.path) else {
                    throw NSError(domain: "DownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create temp ZIP file"])
                }
                
                // Verify ZIP signature
                if zipDataForExtraction.count >= 2 {
                    let signature = zipDataForExtraction.prefix(2)
                    if signature[0] != 0x50 || signature[1] != 0x4B {
                        throw NSError(domain: "DownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP signature"])
                    }
                }
                
                // Ensure destination directory exists and is empty (ZIPFoundation requires this)
                if fileManager.fileExists(atPath: absoluteDestURL.path) {
                    if let existingContents = try? fileManager.contentsOfDirectory(at: absoluteDestURL, includingPropertiesForKeys: nil, options: []), !existingContents.isEmpty {
                        try fileManager.removeItem(at: absoluteDestURL)
                    }
                }
                
                // Create destination directory (must be empty for ZIPFoundation)
                if !fileManager.fileExists(atPath: absoluteDestURL.path) {
                    try fileManager.createDirectory(at: absoluteDestURL, withIntermediateDirectories: true, attributes: nil)
                }
                
                // Verify destination is empty and writable
                if let destContents = try? fileManager.contentsOfDirectory(at: absoluteDestURL, includingPropertiesForKeys: nil, options: []), !destContents.isEmpty {
                    throw NSError(domain: "DownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Destination directory is not empty"])
                }
                
                guard fileManager.isWritableFile(atPath: absoluteDestURL.path) else {
                    throw NSError(domain: "DownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Destination directory is not writable"])
                }
                
                // Open Archive with Data (more reliable than file URL)
                let archive: Archive
                do {
                    archive = try Archive(data: zipDataForExtraction, accessMode: .read)
                } catch {
                    // If Data fails, try with file URL
                    guard let tempURL = finalTempZipURL else {
                        throw NSError(domain: "DownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Temp ZIP URL not available"])
                    }
                    archive = try Archive(url: tempURL, accessMode: .read)
                }
                
                // Extract each entry
                for entry in archive {
                    let entryPath = entry.path
                    let entryURL = absoluteDestURL.appendingPathComponent(entryPath)
                    
                    // Check if entry is a directory (path ends with /)
                    if entryPath.hasSuffix("/") {
                        if !fileManager.fileExists(atPath: entryURL.path) {
                            try fileManager.createDirectory(at: entryURL, withIntermediateDirectories: true, attributes: nil)
                        }
                    } else {
                        // It's a file - extract it
                        let parentDir = entryURL.deletingLastPathComponent()
                        if parentDir.path != absoluteDestURL.path && !fileManager.fileExists(atPath: parentDir.path) {
                            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
                        }
                        
                        let fileEntryURL = URL(fileURLWithPath: entryURL.path)
                        _ = try archive.extract(entry, to: fileEntryURL, skipCRC32: false)
                    }
                }
                
                // Clean up temp ZIP file immediately after extraction
                if let tempURL = finalTempZipURL {
                    try? fileManager.removeItem(at: tempURL)
                }
                
                // Flatten wrapper folder: if only one folder exists and it's not "app", move contents up
                if let contents = try? fileManager.contentsOfDirectory(at: absoluteDestURL, includingPropertiesForKeys: [.isDirectoryKey], options: []),
                   contents.count == 1,
                   let wrapper = contents.first,
                   (try? wrapper.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                   wrapper.lastPathComponent != "app" {
                    if let wrapperContents = try? fileManager.contentsOfDirectory(at: wrapper, includingPropertiesForKeys: nil, options: []) {
                        for item in wrapperContents {
                            let dest = absoluteDestURL.appendingPathComponent(item.lastPathComponent)
                            if fileManager.fileExists(atPath: dest.path) {
                                try? fileManager.removeItem(at: dest)
                            }
                            try? fileManager.moveItem(at: item, to: dest)
                        }
                        try? fileManager.removeItem(at: wrapper)
                    }
                }
            } catch let archiveError as Archive.ArchiveError {
                // Clean up temp ZIP file on error
                if let tempURL = finalTempZipURL {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                
                DispatchQueue.main.async {
                    self.metricsReporter.reportEvent(
                        appId: appId,
                        version: version,
                        eventType: "ZipExtractFailed",
                        message: "ArchiveError: \(archiveError.localizedDescription)",
                        metadata: nil
                    )
                    completion(.failure(archiveError))
                }
                return
            } catch {
                // Clean up temp ZIP file on error
                if let tempURL = finalTempZipURL {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                
                DispatchQueue.main.async {
                    self.metricsReporter.reportEvent(
                        appId: appId,
                        version: version,
                        eventType: "ZipExtractFailed",
                        message: error.localizedDescription,
                        metadata: nil
                    )
                    completion(.failure(error))
                }
                return
            }
            
            DispatchQueue.main.async {
                // Extraction successful - continue with post-processing
                let extractedPath = self.storageManager.extractedPath(for: appId)
                
                // Flatten directory structure - move all contents from subdirectory to root
                self.flattenDirectoryStructure(from: extractedPath, appId: appId)
                
                // Verify extraction was successful by checking if index.html exists
                Thread.sleep(forTimeInterval: 0.1)
                
                let indexPath = self.storageManager.indexPath(for: appId)
                
                if indexPath == nil {
                    let directAppPath = extractedPath.appendingPathComponent("app").appendingPathComponent("index.html")
                    if FileManager.default.fileExists(atPath: directAppPath.path) {
                        let error = NSError(
                            domain: "DownloadManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "index.html found but path resolution failed"]
                        )
                        self.metricsReporter.reportEvent(
                            appId: appId,
                            version: version,
                            eventType: "ZipExtractFailed",
                            message: "index.html found but path resolution failed",
                            metadata: nil
                        )
                        completion(.failure(error))
                        return
                    }
                    
                    let error = NSError(
                        domain: "DownloadManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "index.html not found in extracted files"]
                    )
                    self.metricsReporter.reportEvent(
                        appId: appId,
                        version: version,
                        eventType: "ZipExtractFailed",
                        message: "index.html not found in extracted files",
                        metadata: nil
                    )
                    completion(.failure(error))
                    return
                }
                
                // Report extraction success
                self.metricsReporter.reportEvent(
                    appId: appId,
                    version: version,
                    eventType: "ZipExtracted",
                    message: nil,
                    metadata: nil
                )
                
                // Clean up original downloaded ZIP file after successful extraction
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: zipPath.path) {
                    try? fileManager.removeItem(at: zipPath)
                }
                
                // Store version
                VersionManager.shared.storeVersion(version, for: appId)
                completion(.success(()))
            }
        }
    }
    
    /// Recursively verify extracted files
    private func verifyExtractedFiles(at directory: URL, fileManager: FileManager, indent: String) {
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: []) else {
            log("\(indent)MiniAppsSDK: [Could not read directory: \(directory.path)]")
            return
        }
        
        log("\(indent)MiniAppsSDK: Directory: \(directory.lastPathComponent) contains \(contents.count) items:")
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
            let status = exists ? "✓" : "✗"
            log("\(indent)MiniAppsSDK:   \(status) \(item.lastPathComponent)\(isDir ? " (directory)" : " (file)\(size)")")
            
            // Recursively check subdirectories
            if isDir && indent.count < 12 {
                verifyExtractedFiles(at: item, fileManager: fileManager, indent: indent + "    ")
            }
        }
    }
    
    /// Recursively log directory structure for debugging
    private func logDirectoryStructure(at directory: URL, indent: String) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: []) else {
            log("\(indent)MiniAppsSDK: [Could not read directory]")
            return
        }
        
        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let size: String
            if isDir {
                size = ""
            } else {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: item.path)[.size] as? Int64) ?? 0
                size = " (\(fileSize) bytes)"
            }
            log("\(indent)MiniAppsSDK:   - \(item.lastPathComponent)\(isDir ? " (directory)" : " (file)\(size)")")
            
            // Recursively log subdirectories (limit depth to avoid too much output)
            if isDir && indent.count < 6 { // Max 3 levels deep
                logDirectoryStructure(at: item, indent: indent + "    ")
            }
        }
    }
    
    /// Find index.html in directory or subdirectories
    private func findIndexHTML(in directory: URL) -> URL? {
        let fileManager = FileManager.default
        let indexPath = directory.appendingPathComponent("index.html")
        
        if fileManager.fileExists(atPath: indexPath.path) {
            log("MiniAppsSDK: Found index.html at root: \(indexPath.path)")
            return indexPath
        }
        
        // Search in subdirectories
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            log("MiniAppsSDK: Could not create directory enumerator")
            return nil
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "index.html" {
                log("MiniAppsSDK: Found index.html in subdirectory: \(fileURL.path)")
                return fileURL
            }
        }
        
        log("MiniAppsSDK: index.html not found in directory: \(directory.path)")
        // List all files for debugging
        if let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: []) {
            log("MiniAppsSDK: Extracted directory contents:")
            for item in contents {
                log("MiniAppsSDK:   - \(item.lastPathComponent)")
            }
        }
        
        return nil
    }
    
    /// Flatten directory structure - move all contents from wrapper folder to appId root
    /// Handles case where ZIP creates a folder (e.g., "to-do-list") containing app files
    private func flattenDirectoryStructure(from directory: URL, appId: String) {
        let fileManager = FileManager.default
        
        log("MiniAppsSDK: ========== Flattening Directory Structure ==========")
        log("MiniAppsSDK: Target directory: \(directory.path)")
        
        // Check if index.html already exists at root (in app/ subfolder is OK too)
        let indexPath = directory.appendingPathComponent("index.html")
        let appIndexPath = directory.appendingPathComponent("app").appendingPathComponent("index.html")
        
        if fileManager.fileExists(atPath: indexPath.path) || fileManager.fileExists(atPath: appIndexPath.path) {
            log("MiniAppsSDK: Files already at correct location, no flattening needed")
            return
        }
        
        // Get all items in the directory
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: []) else {
            log("MiniAppsSDK: ERROR: Could not read directory contents")
            return
        }
        
        log("MiniAppsSDK: Found \(contents.count) items in directory")
        
        // Find the wrapper folder (should be the only directory, or the one containing app/ or index.html)
        var wrapperFolder: URL? = nil
        
        for item in contents {
            guard let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true else {
                // Skip files at root level
                continue
            }
            
            let folderName = item.lastPathComponent
            log("MiniAppsSDK: Found subdirectory: \(folderName)")
            
            // Check if this folder contains app/ or index.html or manifest.json
            let hasAppFolder = fileManager.fileExists(atPath: item.appendingPathComponent("app").path)
            let hasIndexHTML = fileManager.fileExists(atPath: item.appendingPathComponent("index.html").path)
            let hasManifest = fileManager.fileExists(atPath: item.appendingPathComponent("manifest.json").path)
            
            if hasAppFolder || hasIndexHTML || hasManifest {
                wrapperFolder = item
                log("MiniAppsSDK: ✓ Found wrapper folder: \(folderName)")
                break
            }
        }
        
        guard let wrapper = wrapperFolder else {
            log("MiniAppsSDK: No wrapper folder found, structure might already be correct")
            return
        }
        
        // Move all contents from wrapper folder to root
        guard let wrapperContents = try? fileManager.contentsOfDirectory(at: wrapper, includingPropertiesForKeys: nil, options: []) else {
            log("MiniAppsSDK: ERROR: Could not read wrapper folder contents")
            return
        }
        
        log("MiniAppsSDK: Moving \(wrapperContents.count) items from '\(wrapper.lastPathComponent)' to root...")
        
        for item in wrapperContents {
            let itemName = item.lastPathComponent
            let destination = directory.appendingPathComponent(itemName)
            
            do {
                // Remove destination if exists
                if fileManager.fileExists(atPath: destination.path) {
                    log("MiniAppsSDK: Removing existing: \(itemName)")
                    try fileManager.removeItem(at: destination)
                }
                
                // Move item to root
                log("MiniAppsSDK: Moving \(itemName) to root")
                try fileManager.moveItem(at: item, to: destination)
            } catch {
                log("MiniAppsSDK: ERROR: Failed to move \(itemName): \(error.localizedDescription)")
            }
        }
        
        // Remove empty wrapper folder
        do {
            try fileManager.removeItem(at: wrapper)
            log("MiniAppsSDK: ✓ Removed empty wrapper folder: \(wrapper.lastPathComponent)")
        } catch {
            log("MiniAppsSDK: WARNING: Could not remove wrapper folder: \(error.localizedDescription)")
        }
        
        // Verify final structure
        log("MiniAppsSDK: Final directory structure:")
        if let finalContents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: []) {
            for item in finalContents {
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                log("MiniAppsSDK:   ✓ \(item.lastPathComponent) (\(isDir ? "directory" : "file"))")
            }
        }
        
        log("MiniAppsSDK: ========== Flattening Complete ==========")
    }
    
    private func getFileSizeMetadata(for url: URL) -> String? {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64 {
            return "{\"sizeBytes\":\(size)}"
        }
        return nil
    }
}
