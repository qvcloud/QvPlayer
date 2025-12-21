import Foundation
import Darwin

class WebServer {
    static let shared = WebServer()
    private let port: UInt16 = 10001
    
    private class Client {
        let id = UUID()
        let fd: Int32
        var source: DispatchSourceRead?
        var buffer = Data()
        var expectedContentLength: Int = 0
        var headersReceived = false
        var headerEndIndex: Int = 0
        
        init(fd: Int32) {
            self.fd = fd
        }
    }
    
    private var clients: [UUID: Client] = [:]
    private let queue = DispatchQueue(label: "com.qvplayer.webserver")
    private var listeningFD: Int32 = -1
    private var listeningSource: DispatchSourceRead?
    
    private var currentStatus: [String: Any] = ["isPlaying": false, "title": "Idle", "currentTime": 0, "duration": 0]
    
    private init() {
        NotificationCenter.default.addObserver(forName: .playerStatusDidUpdate, object: nil, queue: nil) { [weak self] notification in
            if let status = notification.userInfo?["status"] as? [String: Any] {
                self?.currentStatus = status
            }
        }
    }
    
    var serverURL: String? {
        if let ip = getIPAddress() {
            return "http://\(ip):\(port)"
        }
        return nil
    }
    
    func start() {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd != -1 else {
            print("Failed to create socket")
            return
        }
        
        var value: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int32>.size))
        
        // Set non-blocking
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        
        var addr = sockaddr_in()
        addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(self.port).bigEndian
        addr.sin_addr.s_addr = in_addr_t(0) // INADDR_ANY
        
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        if bindResult == -1 {
            let errorMsg = "Bind failed: \(String(cString: strerror(errno)))"
            print(errorMsg)
            DebugLogger.shared.error(errorMsg)
            close(fd)
            return
        }
        
        if listen(fd, 5) == -1 {
            print("Listen failed")
            DebugLogger.shared.error("Listen failed")
            close(fd)
            return
        }
        
        self.listeningFD = fd
        print("Server ready on port \(self.port)")
        DebugLogger.shared.info("Server ready on port \(self.port)")
        
        if let ip = getIPAddress() {
            let url = "http://\(ip):\(port)"
            DispatchQueue.main.async {
                DebugLogger.shared.serverURL = url
            }
        }
        
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        source.resume()
        self.listeningSource = source
    }
    
    func stop() {
        listeningSource?.cancel()
        listeningSource = nil
        if listeningFD != -1 {
            close(listeningFD)
            listeningFD = -1
        }
        DispatchQueue.main.async {
            DebugLogger.shared.serverURL = "Stopped"
        }
        // Close all client connections
        for client in clients.values {
            client.source?.cancel()
            close(client.fd)
        }
        clients.removeAll()
    }
    
    private func acceptConnection() {
        var addr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let clientFD = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(listeningFD, $0, &len)
            }
        }
        
        guard clientFD != -1 else { return }
        
        // Set non-blocking for client
        let flags = fcntl(clientFD, F_GETFL)
        _ = fcntl(clientFD, F_SETFL, flags | O_NONBLOCK)
        
        let client = Client(fd: clientFD)
        self.clients[client.id] = client
        
        let source = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: queue)
        source.setEventHandler { [weak self] in
            self?.readData(from: client)
        }
        source.setCancelHandler {
            close(clientFD)
        }
        source.resume()
        client.source = source
    }
    
    private func readData(from client: Client) {
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(client.fd, &buffer, buffer.count)
        
        if bytesRead > 0 {
            let data = Data(bytes: buffer, count: bytesRead)
            client.buffer.append(data)
            self.checkRequest(client: client)
        } else if bytesRead == 0 {
            // EOF
            closeClient(client)
        } else {
            if errno != EAGAIN && errno != EWOULDBLOCK {
                print("Read error: \(String(cString: strerror(errno)))")
                closeClient(client)
            }
        }
    }
    
    private func closeClient(_ client: Client) {
        client.source?.cancel()
        client.source = nil
        // fd is closed in cancel handler
        self.clients.removeValue(forKey: client.id)
    }
    
    private func checkRequest(client: Client) {
        if !client.headersReceived {
            if let range = client.buffer.range(of: "\r\n\r\n".data(using: .utf8)!) {
                let headersData = client.buffer.subdata(in: 0..<range.lowerBound)
                let headersString = String(data: headersData, encoding: .utf8) ?? ""
                
                let lines = headersString.components(separatedBy: "\r\n")
                var contentLengthFound = false
                for line in lines {
                    if line.lowercased().hasPrefix("content-length:") {
                        let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                        client.expectedContentLength = Int(value) ?? 0
                        print("✅ [WebServer] Parsed Content-Length: \(client.expectedContentLength) from line: '\(line)'")
                        contentLengthFound = true
                        break
                    }
                }
                
                if !contentLengthFound {
                    client.expectedContentLength = 0
                    // Only warn if it's a POST/PUT request where we might expect a body
                    if headersString.uppercased().contains("POST ") || headersString.uppercased().contains("PUT ") {
                        print("⚠️ [WebServer] Content-Length not found in headers for POST/PUT")
                    }
                }
                
                client.headersReceived = true
                client.headerEndIndex = range.upperBound
            }
        }
        
        if client.headersReceived {
            let totalExpected = client.headerEndIndex + client.expectedContentLength
            if client.buffer.count >= totalExpected {
                self.processRequest(data: client.buffer, client: client)
            }
        }
    }
    
    private func processRequest(data: Data, client: Client) {
        guard let range = data.range(of: "\r\n\r\n".data(using: .utf8)!) else {
            closeClient(client)
            return
        }
        
        let headersData = data.subdata(in: 0..<range.lowerBound)
        guard let headersString = String(data: headersData, encoding: .utf8) else { return }
        
        let lines = headersString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return }
        let parts = requestLine.components(separatedBy: " ")
        
        guard parts.count >= 2 else { return }
        let method = parts[0]
        let fullPath = parts[1]
        
        guard let urlComponents = URLComponents(string: "http://localhost\(fullPath)") else { return }
        let path = urlComponents.path
        let queryItems = urlComponents.queryItems ?? []
        
        let bodyData = data.subdata(in: range.upperBound..<data.count)
        let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
        
        if path != "/api/v1/status" {
            var logBody = bodyString
            if logBody.count > 500 {
                logBody = String(logBody.prefix(500)) + "...(truncated)"
            }
            let bodyLogPart = logBody.isEmpty ? "" : " Body: \(logBody)"
            
            print("Request: \(method) \(fullPath)")
            DebugLogger.shared.info("REQ: \(method) \(fullPath)\(bodyLogPart)")
        }
        
        // Static Content
        if method == "GET" && path == "/" {
            sendResponse(client: client, body: WebAssets.htmlContent)
            return
        } else if method == "GET" && path == "/api/v1/docs" {
             sendResponse(client: client, body: WebAssets.apiDocsContent)
             return
        }
        
        // API Handlers via Controller
        var responseBody: String?
        var success = true
        var message: String?
        
        if method == "GET" && (path == "/api/v1/media" || path == "/api/v1/videos") {
            responseBody = WebAPIController.shared.handleGetVideos()
            if responseBody == nil { success = false; message = "Failed to serialize" }
        } else if method == "GET" && path == "/api/v1/status" {
            responseBody = WebAPIController.shared.handleGetStatus(currentStatus: currentStatus)
        } else if method == "POST" && path == "/api/v1/videos" {
            (success, message) = WebAPIController.shared.handleAddVideo(body: bodyString)
        } else if method == "DELETE" && path == "/api/v1/videos" {
            (success, message) = WebAPIController.shared.handleDeleteVideo(queryItems: queryItems)
        } else if method == "PUT" && path == "/api/v1/videos" {
            (success, message) = WebAPIController.shared.handleUpdateVideo(queryItems: queryItems, body: bodyString)
        } else if method == "DELETE" && path == "/api/v1/videos/batch" {
            (success, message) = WebAPIController.shared.handleBatchDeleteVideo(body: bodyString)
        } else if method == "PUT" && path == "/api/v1/videos/batch/group" {
            (success, message) = WebAPIController.shared.handleBatchUpdateGroup(body: bodyString)
        } else if method == "PUT" && path == "/api/v1/videos/sort" {
            (success, message) = WebAPIController.shared.handleUpdateSortOrder(body: bodyString)
        } else if method == "DELETE" && path == "/api/v1/groups" {
            (success, message) = WebAPIController.shared.handleDeleteGroup(body: bodyString)
        } else if method == "POST" && path.hasPrefix("/api/v1/control/") {
            (success, message) = WebAPIController.shared.handleControl(path: path, queryItems: queryItems)
        } else if method == "POST" && path == "/api/v1/queue" {
            (success, message) = WebAPIController.shared.handleAddToQueue(body: bodyString)
        } else if method == "PUT" && path == "/api/v1/queue/sort" {
            (success, message) = WebAPIController.shared.handleUpdateQueueSortOrder(body: bodyString)
        } else if method == "PUT" && path == "/api/v1/queue/loop" {
            (success, message) = WebAPIController.shared.handleUpdateQueueLoopStatus(body: bodyString)
        } else if method == "PUT" && path == "/api/v1/debug" {
            (success, message) = WebAPIController.shared.handleUpdateDebugOverlay(body: bodyString)
        } else if method == "DELETE" && path == "/api/v1/queue" {
            (success, message) = WebAPIController.shared.handleClearQueue(queryItems: queryItems)
        }
        // Uploads (Keep local for now due to complexity)
        else if method == "POST" && path == "/api/v1/upload" {
            handleUpload(client: client, headers: headersString, body: bodyData)
            return
        } else if method == "POST" && path == "/api/v1/upload/remote" {
            handleRemoteUpload(client: client, body: bodyString)
            return
        }
        // Legacy
        else if method == "POST" && path == "/api/v1/delete" {
             sendResponse(client: client, status: "400 Bad Request", body: "Legacy API deprecated")
             return
        } else {
            sendResponse(client: client, status: "404 Not Found", body: "Not Found")
            return
        }
        
        if let body = responseBody {
            sendResponse(client: client, contentType: "application/json", body: body)
        } else if success {
            let msg = message ?? "Success"
            sendResponse(client: client, contentType: "application/json", body: "{\"success\": true, \"message\": \"\(msg)\"}")
        } else {
            let msg = message ?? "Unknown Error"
            sendResponse(client: client, status: "500 Internal Server Error", contentType: "application/json", body: "{\"error\": \"\(msg)\"}")
        }
    }
    
    // MARK: - API Handlers
    // Handlers moved to WebAPIController

    
    private func handleUpload(client: Client, headers: String, body: Data) {
        print("📂 [Upload] Starting upload handling. Body size: \(body.count)")
        
        // 1. Extract Boundary
        var boundary: String?
        let lines = headers.components(separatedBy: "\r\n")
        for line in lines {
            if line.lowercased().hasPrefix("content-type:") {
                let parts = line.components(separatedBy: ";")
                for part in parts {
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if trimmed.lowercased().hasPrefix("boundary=") {
                        var b = String(trimmed.dropFirst("boundary=".count))
                        if b.hasPrefix("\"") && b.hasSuffix("\"") {
                            b = String(b.dropFirst().dropLast())
                        }
                        boundary = b
                        break
                    }
                }
            }
            if boundary != nil { break }
        }
        
        guard let boundary = boundary else {
            print("❌ [Upload] Boundary not found in headers")
            sendResponse(client: client, status: "400 Bad Request", contentType: "application/json", body: "{\"error\": \"Invalid Content-Type or Boundary missing\"}")
            return
        }
        
        // 2. Parse Multipart Data
        let boundaryData = ("--" + boundary).data(using: .utf8)!
        var parts: [Data] = []
        
        var currentRange = body.startIndex..<body.endIndex
        
        // Find first boundary
        guard let firstBoundaryRange = body.range(of: boundaryData, options: [], in: currentRange) else {
             sendResponse(client: client, status: "400 Bad Request", contentType: "application/json", body: "{\"error\": \"Boundary not found\"}")
             return
        }
        
        currentRange = firstBoundaryRange.upperBound..<body.endIndex
        
        while true {
            guard let nextBoundaryRange = body.range(of: boundaryData, options: [], in: currentRange) else {
                break
            }
            
            let partData = body.subdata(in: currentRange.lowerBound..<nextBoundaryRange.lowerBound)
            parts.append(partData)
            
            currentRange = nextBoundaryRange.upperBound..<body.endIndex
        }
        
        var uploadedFiles: [(filename: String, data: Data)] = []
        var uploadedGroup: String?
        
        let separator = "\r\n\r\n".data(using: .utf8)!
        
        for part in parts {
            // Find headers end
            guard let headersEndRange = part.range(of: separator) else { continue }
            
            let headersData = part.subdata(in: 0..<headersEndRange.lowerBound)
            let headersString = String(data: headersData, encoding: .utf8) ?? ""
            
            // Extract content
            var contentData = part.subdata(in: headersEndRange.upperBound..<part.count)
            
            // Strip trailing CRLF
            if contentData.count >= 2 {
                let suffix = contentData.subdata(in: contentData.count-2..<contentData.count)
                if suffix == "\r\n".data(using: .utf8)! {
                    contentData = contentData.subdata(in: 0..<contentData.count-2)
                }
            }
            
            if headersString.contains("filename=\"") {
                // It's a file
                if let filenameRange = headersString.range(of: "filename=\"") {
                    let afterFilename = headersString[filenameRange.upperBound...]
                    if let endQuote = afterFilename.firstIndex(of: "\"") {
                        let filename = String(afterFilename[..<endQuote])
                        uploadedFiles.append((filename, contentData))
                    }
                }
            } else if headersString.contains("name=\"group\"") {
                // It's the group field
                uploadedGroup = String(data: contentData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        guard !uploadedFiles.isEmpty else {
            sendResponse(client: client, status: "400 Bad Request", contentType: "application/json", body: "{\"error\": \"No file uploaded\"}")
            return
        }
        
        var successCount = 0
        var errorMessages: [String] = []
        
        for (var filename, fileData) in uploadedFiles {
            // Sanitize filename
            filename = filename.replacingOccurrences(of: "/", with: "_")
                               .replacingOccurrences(of: "\\", with: "_")
            
            // 3. Process File
            if filename.lowercased().hasSuffix(".m3u") || filename.lowercased().hasSuffix(".m3u8") {
                // Handle Playlist Import
                if let content = String(data: fileData, encoding: .utf8) {
                    do {
                        // Use uploaded group name if provided, otherwise use filename
                        let groupName = (uploadedGroup?.isEmpty == false) ? uploadedGroup! : (filename as NSString).deletingPathExtension
                        try MediaManager.shared.appendMediaFromM3U(content: content, customGroupName: groupName)
                        successCount += 1
                    } catch {
                        errorMessages.append("Failed to import playlist \(filename): \(error.localizedDescription)")
                    }
                } else {
                    errorMessages.append("Invalid playlist encoding for \(filename)")
                }
                continue
            }
            
            // 4. Save File to Cache (for non-playlist files)
            do {
                let fileURL = try CacheManager.shared.saveUploadedFile(data: fileData, filename: filename)
                
                // 5. Add to Playlist
                let encodedFilename = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
                let localURLString = "localcache://\(encodedFilename)"
                
                let targetGroup = (uploadedGroup?.isEmpty == false) ? uploadedGroup! : "Local Uploads"
                
                try MediaManager.shared.appendVideo(title: filename, url: localURLString, group: targetGroup)
                
                successCount += 1
            } catch {
                errorMessages.append("Failed to save \(filename): \(error.localizedDescription)")
            }
        }
        
        if successCount > 0 {
            let message = errorMessages.isEmpty ? "Successfully uploaded \(successCount) files" : "Uploaded \(successCount) files. Errors: \(errorMessages.joined(separator: "; "))"
            sendResponse(client: client, contentType: "application/json", body: "{\"success\": true, \"message\": \"\(message)\"}")
        } else {
            sendResponse(client: client, status: "500 Internal Server Error", contentType: "application/json", body: "{\"error\": \"Failed to upload files: \(errorMessages.joined(separator: "; "))\"}")
        }
    }
    
    private func handleRemoteUpload(client: Client, body: String) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = json["url"] as? String,
              let url = URL(string: urlString) else {
            sendResponse(client: client, status: "400 Bad Request", contentType: "application/json", body: "{\"error\": \"Invalid URL\"}")
            return
        }
        
        let name = json["name"] as? String
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let content = String(data: data, encoding: .utf8) else {
                    throw NSError(domain: "WebServer", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid content encoding"])
                }
                
                let groupName = name ?? url.lastPathComponent
                
                // Dispatch to main queue to ensure thread safety with MediaManager if needed, 
                // though MediaManager isn't strictly main-actor bound, it's good practice for shared state.
                // However, since we are in a Task, we can just call it. 
                // But we need to be careful about sendResponse which uses the socket.
                
                DispatchQueue.main.async {
                    do {
                        try MediaManager.shared.appendMediaFromM3U(content: content, customGroupName: groupName)
                        self.queue.async {
                            self.sendResponse(client: client, contentType: "application/json", body: "{\"success\": true, \"message\": \"Remote playlist imported successfully\"}")
                        }
                    } catch {
                        self.queue.async {
                            self.sendResponse(client: client, status: "500 Internal Server Error", contentType: "application/json", body: "{\"error\": \"Failed to import remote playlist: \(error.localizedDescription)\"}")
                        }
                    }
                }
            } catch {
                self.queue.async {
                    self.sendResponse(client: client, status: "500 Internal Server Error", contentType: "application/json", body: "{\"error\": \"Failed to download remote playlist: \(error.localizedDescription)\"}")
                }
            }
        }
    }
    
    private func parseParams(_ body: String) -> [String: String] {
        var result: [String: String] = [:]
        let params = body.components(separatedBy: "&")
        for param in params {
            let pair = param.components(separatedBy: "=")
            if pair.count == 2 {
                let key = pair[0]
                let value = pair[1].replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? pair[1]
                result[key] = value
            }
        }
        return result
    }
    
    private func sendResponse(client: Client, status: String = "200 OK", contentType: String = "text/html", body: String) {
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        Cache-Control: no-cache, no-store, must-revalidate\r
        Pragma: no-cache\r
        Expires: 0\r
        \r
        \(body)
        """
        
        if let data = response.data(using: .utf8) {
            data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
                guard let baseAddress = buffer.baseAddress else { return }
                
                var offset = 0
                let total = data.count
                
                while offset < total {
                    let remaining = total - offset
                    let written = write(client.fd, baseAddress.advanced(by: offset), remaining)
                    
                    if written < 0 {
                        if errno == EAGAIN || errno == EWOULDBLOCK {
                            var pfd = pollfd(fd: client.fd, events: Int16(POLLOUT), revents: 0)
                            let ret = poll(&pfd, 1, 5000) // 5s timeout
                            if ret <= 0 {
                                print("Write timeout or poll error")
                                break
                            }
                        } else {
                            print("Write failed: \(String(cString: strerror(errno)))")
                            break
                        }
                    } else {
                        offset += written
                    }
                }
            }
        }
        
        closeClient(client)
    }
    
    // Batch handlers moved to WebAPIController

    
    // Helper to get IP Address
    func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                
                // Check for IPv4 only
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    
                    // Ignore loopback
                    if name == "lo0" { continue }
                    
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    
                    let ipAddress = String(cString: hostname)
                    
                    // Prefer en0 (WiFi) or en1 (Ethernet)
                    if name == "en0" || name == "en1" {
                        address = ipAddress
                        break // Found a preferred interface
                    }
                    
                    // If we haven't found a preferred one yet, store this one
                    if address == nil {
                        address = ipAddress
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}
