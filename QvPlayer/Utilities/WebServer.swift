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
        // Only convert to string if needed, and be careful with binary data
        let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
        
        if path != "/api/v1/status" {
            print("Request: \(method) \(path)")
            DebugLogger.shared.info("REQ: \(method) \(path)")
        }
        
        if method == "GET" && path == "/" {
            sendResponse(client: client, body: WebAssets.htmlContent)
        } else if method == "GET" && path == "/api/v1/docs" {
             sendResponse(client: client, body: WebAssets.apiDocsContent)
        } 
        // MARK: - API Endpoints
        else if method == "GET" && (path == "/api/v1/playlist" || path == "/api/v1/videos") {
            handleGetVideos(client: client)
        } else if method == "GET" && path == "/api/v1/status" {
            handleGetStatus(client: client)
        } else if method == "POST" && path == "/api/v1/videos" {
            handleAddVideo(client: client, body: bodyString)
        } else if method == "DELETE" && path == "/api/v1/videos" {
            handleDeleteVideo(client: client, queryItems: queryItems)
        } else if method == "PUT" && path == "/api/v1/videos" {
            handleUpdateVideo(client: client, queryItems: queryItems, body: bodyString)
        } else if method == "POST" && path == "/api/v1/playlist" {
            handleReplacePlaylist(client: client, body: bodyString)
        }
        // MARK: - Control Endpoints
        else if method == "POST" && path.hasPrefix("/api/v1/control/") {
            handleControl(client: client, path: path, queryItems: queryItems)
        }
        // MARK: - Upload Endpoint
        else if method == "POST" && path == "/api/v1/upload" {
            handleUpload(client: client, headers: headersString, body: bodyData)
        }
        // MARK: - Legacy / Form Endpoints
        else if method == "POST" && path == "/api/v1/delete" {
            // Legacy form support
            let params = parseParams(bodyString)
            if let indexStr = params["index"], let index = Int(indexStr) {
                PlaylistManager.shared.deleteVideo(at: index)
                sendResponse(client: client, contentType: "application/json", body: "{\"success\": true}")
            } else {
                sendResponse(client: client, status: "400 Bad Request", body: "Missing index")
            }
        } else if method == "POST" && path == "/api/v1/edit" {
            // Legacy form support
            let params = parseParams(bodyString)
            if let indexStr = params["index"], let index = Int(indexStr),
               let title = params["title"], let url = params["url"] {
                let group = params["group"]
                PlaylistManager.shared.updateVideo(at: index, title: title, url: url, group: group)
                sendResponse(client: client, contentType: "application/json", body: "{\"success\": true}")
            } else {
                sendResponse(client: client, status: "400 Bad Request", body: "Missing parameters")
            }
        } else if method == "POST" && path == "/update" {
            // Legacy form support
            let decodedBody = bodyString.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? bodyString
            var m3uContent = decodedBody
            if decodedBody.hasPrefix("playlist=") {
                m3uContent = String(decodedBody.dropFirst(9))
            }
            PlaylistManager.shared.savePlaylist(content: m3uContent)
            let successPage = "<html><body><h1>Playlist Replaced!</h1><a href='/'>Back</a></body></html>"
            sendResponse(client: client, body: successPage)
        } else if method == "POST" && path == "/add" {
            // Legacy form support
            let params = parseParams(bodyString)
            if let title = params["title"], let url = params["url"] {
                let group = params["group"]
                PlaylistManager.shared.appendVideo(title: title, url: url, group: group)
                let successPage = "<html><body><h1>Stream Added!</h1><a href='/'>Back</a></body></html>"
                sendResponse(client: client, body: successPage)
            } else {
                sendResponse(client: client, status: "400 Bad Request", body: "Missing title or url")
            }
        } else {
            sendResponse(client: client, status: "404 Not Found", body: "Not Found")
        }
    }
    
    // MARK: - API Handlers
    
    private func handleGetVideos(client: Client) {
        let videos = PlaylistManager.shared.getPlaylistVideos()
        let jsonItems = videos.map { ["title": $0.title, "url": $0.url.absoluteString, "group": $0.group ?? ""] }
        if let data = try? JSONSerialization.data(withJSONObject: jsonItems),
           let jsonString = String(data: data, encoding: .utf8) {
            sendResponse(client: client, contentType: "application/json", body: jsonString)
        } else {
            sendResponse(client: client, status: "500 Internal Server Error", body: "{}")
        }
    }
    
    private func handleGetStatus(client: Client) {
        if let data = try? JSONSerialization.data(withJSONObject: currentStatus),
           let jsonString = String(data: data, encoding: .utf8) {
            sendResponse(client: client, contentType: "application/json", body: jsonString)
        } else {
            sendResponse(client: client, status: "500 Internal Server Error", body: "{}")
        }
    }
    
    private func handleAddVideo(client: Client, body: String) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let title = json["title"],
              let url = json["url"] else {
            sendResponse(client: client, status: "400 Bad Request", body: "{\"error\": \"Invalid JSON or missing fields\"}")
            return
        }
        
        let group = json["group"]
        PlaylistManager.shared.appendVideo(title: title, url: url, group: group)
        sendResponse(client: client, contentType: "application/json", body: "{\"success\": true}")
    }
    
    private func handleDeleteVideo(client: Client, queryItems: [URLQueryItem]) {
        guard let indexStr = queryItems.first(where: { $0.name == "index" })?.value,
              let index = Int(indexStr) else {
            sendResponse(client: client, status: "400 Bad Request", body: "{\"error\": \"Missing or invalid index parameter\"}")
            return
        }
        
        PlaylistManager.shared.deleteVideo(at: index)
        sendResponse(client: client, contentType: "application/json", body: "{\"success\": true}")
    }
    
    private func handleUpdateVideo(client: Client, queryItems: [URLQueryItem], body: String) {
        guard let indexStr = queryItems.first(where: { $0.name == "index" })?.value,
              let index = Int(indexStr) else {
            sendResponse(client: client, status: "400 Bad Request", body: "{\"error\": \"Missing or invalid index parameter\"}")
            return
        }
        
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let title = json["title"],
              let url = json["url"] else {
            sendResponse(client: client, status: "400 Bad Request", body: "{\"error\": \"Invalid JSON or missing fields\"}")
            return
        }
        
        let group = json["group"]
        PlaylistManager.shared.updateVideo(at: index, title: title, url: url, group: group)
        sendResponse(client: client, contentType: "application/json", body: "{\"success\": true}")
    }
    
    private func handleReplacePlaylist(client: Client, body: String) {
        // Check if body is JSON or raw M3U
        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let content = json["content"] {
            PlaylistManager.shared.savePlaylist(content: content)
        } else {
            // Assume raw text
            PlaylistManager.shared.savePlaylist(content: body)
        }
        sendResponse(client: client, contentType: "application/json", body: "{\"success\": true}")
    }
    
    private func handleControl(client: Client, path: String, queryItems: [URLQueryItem]) {
        let action = path.replacingOccurrences(of: "/api/v1/control/", with: "")
        
        DispatchQueue.main.async {
            DebugLogger.shared.lastRemoteCommand = action
        }
        
        switch action {
        case "play":
            NotificationCenter.default.post(name: .commandPlay, object: nil)
        case "pause":
            NotificationCenter.default.post(name: .commandPause, object: nil)
        case "toggle":
            NotificationCenter.default.post(name: .commandToggle, object: nil)
        case "seek":
            if let secondsStr = queryItems.first(where: { $0.name == "time" })?.value,
               let seconds = Double(secondsStr) {
                NotificationCenter.default.post(name: .commandSeek, object: nil, userInfo: ["seconds": seconds])
            }
        case "play_video":
            if let indexStr = queryItems.first(where: { $0.name == "index" })?.value,
               let index = Int(indexStr) {
                NotificationCenter.default.post(name: .commandPlayVideo, object: nil, userInfo: ["index": index])
            }
        default:
            sendResponse(client: client, status: "400 Bad Request", body: "{\"error\": \"Unknown action\"}")
            return
        }
        
        sendResponse(client: client, contentType: "application/json", body: "{\"success\": true}")
    }
    
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
        
        print("📂 [Upload] Boundary: \(boundary)")
        
        // 2. Find File Data
        let boundaryData = ("--" + boundary).data(using: .utf8)!
        
        // Find start of first part
        guard let firstPartRange = body.range(of: boundaryData) else {
            print("❌ [Upload] First boundary not found in body")
            sendResponse(client: client, status: "400 Bad Request", contentType: "application/json", body: "{\"error\": \"Boundary not found\"}")
            return
        }
        
        let afterFirstBoundary = body.subdata(in: firstPartRange.upperBound..<body.count)
        
        // Find headers end (\r\n\r\n)
        let separator = "\r\n\r\n".data(using: .utf8)!
        guard let headersEndRange = afterFirstBoundary.range(of: separator) else {
            print("❌ [Upload] Headers end not found")
            sendResponse(client: client, status: "400 Bad Request", contentType: "application/json", body: "{\"error\": \"Headers end not found\"}")
            return
        }
        
        let partHeadersData = afterFirstBoundary.subdata(in: 0..<headersEndRange.lowerBound)
        let partHeadersString = String(data: partHeadersData, encoding: .utf8) ?? ""
        print("📂 [Upload] Part Headers: \(partHeadersString)")
        
        // Extract Filename
        var filename = "uploaded_file.mp4"
        if let filenameRange = partHeadersString.range(of: "filename=\"") {
            let afterFilename = partHeadersString[filenameRange.upperBound...]
            if let endQuote = afterFilename.firstIndex(of: "\"") {
                filename = String(afterFilename[..<endQuote])
            }
        }
        
        // Sanitize filename
        filename = filename.replacingOccurrences(of: "/", with: "_")
                           .replacingOccurrences(of: "\\", with: "_")
        
        // Extract Content
        let contentStart = headersEndRange.upperBound
        let contentData = afterFirstBoundary.subdata(in: contentStart..<afterFirstBoundary.count)
        print("📂 [Upload] Content Data Size: \(contentData.count)")
        
        // Find end boundary
        guard let endBoundaryRange = contentData.range(of: boundaryData) else {
             print("❌ [Upload] End boundary not found. Content tail: \(String(data: contentData.suffix(50), encoding: .ascii) ?? "nil")")
             sendResponse(client: client, status: "400 Bad Request", contentType: "application/json", body: "{\"error\": \"End boundary not found\"}")
             return
        }
        
        var fileDataEnd = endBoundaryRange.lowerBound
        // Strip trailing \r\n if present
        if fileDataEnd >= 2 {
            let potentialCRLF = contentData.subdata(in: fileDataEnd-2..<fileDataEnd)
            if potentialCRLF == "\r\n".data(using: .utf8)! {
                fileDataEnd -= 2
            }
        }
        
        let fileData = contentData.subdata(in: 0..<fileDataEnd)
        
        // 3. Save File to Cache
        do {
            let fileURL = try CacheManager.shared.saveUploadedFile(data: fileData, filename: filename)
            
            // 4. Add to Playlist
            // Use a custom scheme to persist local file references across app launches
            let localURLString = "localcache://\(filename)"
            PlaylistManager.shared.appendVideo(title: filename, url: localURLString, group: "Local Uploads")
            
            sendResponse(client: client, contentType: "application/json", body: "{\"success\": true, \"path\": \"\(fileURL.lastPathComponent)\"}")
        } catch {
            sendResponse(client: client, status: "500 Internal Server Error", contentType: "application/json", body: "{\"error\": \"Failed to save file: \(error)\"}")
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
        \r
        \(body)
        """
        
        if let data = response.data(using: .utf8) {
            data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
                if let baseAddress = buffer.baseAddress {
                    write(client.fd, baseAddress, data.count)
                }
            }
        }
        
        closeClient(client)
    }
    
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
