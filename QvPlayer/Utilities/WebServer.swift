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
        fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        
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
            print("Bind failed: \(String(cString: strerror(errno)))")
            close(fd)
            return
        }
        
        if listen(fd, 5) == -1 {
            print("Listen failed")
            close(fd)
            return
        }
        
        self.listeningFD = fd
        print("Server ready on port \(self.port)")
        
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
        fcntl(clientFD, F_SETFL, flags | O_NONBLOCK)
        
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
        
        print("Request: \(method) \(path)")
        
        if method == "GET" && path == "/" {
            sendResponse(client: client, body: htmlContent)
        } else if method == "GET" && path == "/api/docs" {
             sendResponse(client: client, body: apiDocsContent)
        } 
        // MARK: - API Endpoints
        else if method == "GET" && (path == "/api/playlist" || path == "/api/videos") {
            handleGetVideos(client: client)
        } else if method == "GET" && path == "/api/status" {
            handleGetStatus(client: client)
        } else if method == "POST" && path == "/api/videos" {
            handleAddVideo(client: client, body: bodyString)
        } else if method == "DELETE" && path == "/api/videos" {
            handleDeleteVideo(client: client, queryItems: queryItems)
        } else if method == "PUT" && path == "/api/videos" {
            handleUpdateVideo(client: client, queryItems: queryItems, body: bodyString)
        } else if method == "POST" && path == "/api/playlist" {
            handleReplacePlaylist(client: client, body: bodyString)
        }
        // MARK: - Control Endpoints
        else if method == "POST" && path.hasPrefix("/api/control/") {
            handleControl(client: client, path: path, queryItems: queryItems)
        }
        // MARK: - Upload Endpoint
        else if method == "POST" && path == "/api/upload" {
            handleUpload(client: client, headers: headersString, body: bodyData)
        }
        // MARK: - Legacy / Form Endpoints
        else if method == "POST" && path == "/api/delete" {
            // Legacy form support
            let params = parseParams(bodyString)
            if let indexStr = params["index"], let index = Int(indexStr) {
                PlaylistManager.shared.deleteVideo(at: index)
                sendResponse(client: client, contentType: "application/json", body: "{\"success\": true}")
            } else {
                sendResponse(client: client, status: "400 Bad Request", body: "Missing index")
            }
        } else if method == "POST" && path == "/api/edit" {
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
        let action = path.replacingOccurrences(of: "/api/control/", with: "")
        
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
            PlaylistManager.shared.appendVideo(title: filename, url: fileURL.absoluteString, group: "Local Uploads")
            
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
    
    private var htmlContent: String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>QvPlayer Manager</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; background: #f0f0f0; }
                .container { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); margin-bottom: 20px; }
                h1 { color: #333; }
                h2 { color: #555; border-bottom: 1px solid #eee; padding-bottom: 10px; }
                textarea { width: 100%; height: 200px; margin-bottom: 20px; padding: 10px; border: 1px solid #ddd; border-radius: 8px; font-family: monospace; }
                input[type="text"] { width: 100%; padding: 10px; margin-bottom: 15px; border: 1px solid #ddd; border-radius: 8px; box-sizing: border-box; }
                button { background: #007AFF; color: white; border: none; padding: 10px 20px; border-radius: 8px; font-size: 14px; cursor: pointer; }
                button.secondary { background: #5856D6; }
                button.danger { background: #FF3B30; }
                button.edit { background: #FF9500; }
                button:hover { opacity: 0.9; }
                label { display: block; margin-bottom: 5px; font-weight: bold; color: #666; }
                
                .video-list { list-style: none; padding: 0; }
                .video-item { border-bottom: 1px solid #eee; padding: 15px 0; display: flex; justify-content: space-between; align-items: center; }
                .video-info { flex-grow: 1; margin-right: 15px; overflow: hidden; }
                .video-title { font-weight: bold; margin-bottom: 5px; }
                .video-url { color: #888; font-size: 0.8em; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
                .video-actions { display: flex; gap: 10px; }
                
                /* Modal */
                .modal { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); align-items: center; justify-content: center; }
                .modal.active { display: flex; }
                .modal-content { background: white; padding: 20px; border-radius: 12px; width: 90%; max-width: 500px; }
                .modal-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>QvPlayer Manager</h1>
                
                <h2>Remote Control</h2>
                <div id="playerStatus" style="margin-bottom: 15px; padding: 10px; background: #f8f9fa; border-radius: 8px; border: 1px solid #e9ecef;">
                    <div style="font-weight: bold; margin-bottom: 5px;">Status: <span id="statusText">Idle</span></div>
                    <div style="font-size: 0.9em; color: #666;">Now Playing: <span id="nowPlayingText">-</span></div>
                    <div style="font-size: 0.9em; color: #666;">Time: <span id="timeText">00:00 / 00:00</span></div>
                </div>
                <div style="display: flex; gap: 10px; margin-bottom: 20px;">
                    <button onclick="control('play')">Play</button>
                    <button onclick="control('pause')">Pause</button>
                    <button onclick="control('toggle')" class="secondary">Toggle</button>
                </div>
                <div style="display: flex; gap: 10px; align-items: center;">
                    <button onclick="control('seek', -15)">-15s</button>
                    <button onclick="control('seek', 15)">+15s</button>
                </div>
            </div>
            
            <div class="container">
                <h2>Upload Local File</h2>
                <form id="uploadForm">
                    <input type="file" id="fileInput" name="file" style="margin-bottom: 10px;">
                    <button type="button" onclick="uploadFile()" class="secondary">Upload & Play</button>
                </form>
                <div id="uploadStatus" style="margin-top: 10px; color: #666;"></div>
            </div>
            
            <div class="container">
                <h2>Add Stream</h2>
                <form action="/add" method="POST">
                    <label>Channel Name</label>
                    <input type="text" name="title" placeholder="e.g. CCTV-1" required>
                    <label>Group (Optional)</label>
                    <input type="text" name="group" placeholder="e.g. News">
                    <label>Stream URL (m3u8)</label>
                    <input type="text" name="url" placeholder="http://..." required>
                    <button type="submit" class="secondary">Add to Playlist</button>
                </form>
            </div>

            <div class="container">
                <h2>Current Playlist</h2>
                <ul id="playlist" class="video-list">
                    <!-- Items will be loaded here -->
                </ul>
            </div>

            <div class="container">
                <h2>Replace Full Playlist</h2>
                <p>Paste your M3U playlist content below (This will overwrite existing playlist):</p>
                <form action="/update" method="POST">
                    <textarea name="playlist" placeholder="#EXTM3U..."></textarea>
                    <br>
                    <button type="submit">Replace Playlist</button>
                </form>
            </div>
            
            <!-- Edit Modal -->
            <div id="editModal" class="modal">
                <div class="modal-content">
                    <h2>Edit Stream</h2>
                    <input type="hidden" id="editIndex">
                    <label>Channel Name</label>
                    <input type="text" id="editTitle">
                    <label>Group</label>
                    <input type="text" id="editGroup">
                    <label>Stream URL</label>
                    <input type="text" id="editUrl">
                    <div class="modal-actions">
                        <button onclick="closeModal()" style="background: #888;">Cancel</button>
                        <button onclick="saveEdit()">Save Changes</button>
                    </div>
                </div>
            </div>

            <script>
                let currentVideos = [];
                
                function playVideo(index) {
                    fetch('/api/control/play_video?index=' + index, { method: 'POST' });
                }

                function control(action, time) {
                    let url = '/api/control/' + action;
                    if (time) {
                        url += '?time=' + time;
                    }
                    fetch(url, { method: 'POST' });
                }
                
                function uploadFile() {
                    const fileInput = document.getElementById('fileInput');
                    const file = fileInput.files[0];
                    if (!file) {
                        alert('Please select a file');
                        return;
                    }
                    
                    const formData = new FormData();
                    formData.append('file', file);
                    
                    const statusDiv = document.getElementById('uploadStatus');
                    statusDiv.textContent = 'Uploading...';
                    
                    fetch('/api/upload', {
                        method: 'POST',
                        body: formData
                    })
                    .then(response => response.json())
                    .then(data => {
                        if (data.success) {
                            statusDiv.textContent = 'Upload successful! Added to playlist.';
                            loadPlaylist();
                            fileInput.value = '';
                        } else {
                            statusDiv.textContent = 'Upload failed: ' + (data.error || 'Unknown error');
                        }
                    })
                    .catch(error => {
                        statusDiv.textContent = 'Upload error: ' + error;
                    });
                }
                
                function loadPlaylist() {
                    fetch('/api/playlist')
                        .then(response => response.json())
                        .then(data => {
                            currentVideos = data;
                            const list = document.getElementById('playlist');
                            list.innerHTML = '';
                            data.forEach((video, index) => {
                                const li = document.createElement('li');
                                li.className = 'video-item';
                                li.innerHTML = `
                                    <div class="video-info">
                                        <div class="video-title">
                                            ${escapeHtml(video.title)} 
                                            <span style="font-weight:normal; color:#666; font-size:0.8em; background:#eee; padding:2px 6px; border-radius:4px; margin-left: 8px;">
                                                ${escapeHtml(video.group || 'Ungrouped')}
                                            </span>
                                        </div>
                                        <div class="video-url">${escapeHtml(video.url)}</div>
                                    </div>
                                    <div class="video-actions">
                                        <button onclick="playVideo(${index})">Play on TV</button>
                                        <button class="edit" onclick="openEdit(${index})">Edit</button>
                                        <button class="danger" onclick="deleteVideo(${index})">Delete</button>
                                    </div>
                                `;
                                list.appendChild(li);
                            });
                        });
                }
                
                function deleteVideo(index) {
                    if(confirm('Are you sure you want to delete this stream?')) {
                        fetch('/api/delete', {
                            method: 'POST',
                            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                            body: 'index=' + index
                        }).then(() => loadPlaylist());
                    }
                }
                
                function openEdit(index) {
                    const video = currentVideos[index];
                    document.getElementById('editIndex').value = index;
                    document.getElementById('editTitle').value = video.title;
                    document.getElementById('editGroup').value = video.group || '';
                    document.getElementById('editUrl').value = video.url;
                    document.getElementById('editModal').classList.add('active');
                }
                
                function closeModal() {
                    document.getElementById('editModal').classList.remove('active');
                }
                
                function saveEdit() {
                    const index = document.getElementById('editIndex').value;
                    const title = document.getElementById('editTitle').value;
                    const group = document.getElementById('editGroup').value;
                    const url = document.getElementById('editUrl').value;
                    
                    fetch('/api/edit', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                        body: `index=${index}&title=${encodeURIComponent(title)}&group=${encodeURIComponent(group)}&url=${encodeURIComponent(url)}`
                    }).then(() => {
                        closeModal();
                        loadPlaylist();
                    });
                }
                
                function escapeHtml(text) {
                    return text
                        .replace(/&/g, "&amp;")
                        .replace(/</g, "&lt;")
                        .replace(/>/g, "&gt;")
                        .replace(/"/g, "&quot;")
                        .replace(/'/g, "&#039;");
                }
                
                function updateStatus() {
                    fetch('/api/status')
                        .then(response => response.json())
                        .then(data => {
                            const statusText = document.getElementById('statusText');
                            const nowPlayingText = document.getElementById('nowPlayingText');
                            const timeText = document.getElementById('timeText');
                            
                            if (statusText) {
                                statusText.textContent = data.isPlaying ? 'Playing' : 'Paused';
                                statusText.style.color = data.isPlaying ? '#28a745' : '#dc3545';
                            }
                            
                            if (nowPlayingText) {
                                nowPlayingText.textContent = data.title || '-';
                            }
                            
                            const formatTime = (seconds) => {
                                if (!seconds) return '00:00';
                                const m = Math.floor(seconds / 60);
                                const s = Math.floor(seconds % 60);
                                return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
                            };
                            
                            if (timeText) {
                                timeText.textContent = `${formatTime(data.currentTime)} / ${formatTime(data.duration)}`;
                            }
                        })
                        .catch(console.error);
                }
                
                // Poll every 1 second
                setInterval(updateStatus, 1000);
                updateStatus();
                
                loadPlaylist();
            </script>
        </body>
        </html>
        """
    }
    
    private var apiDocsContent: String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>QvPlayer API Documentation</title>
            <style>
                body { font-family: monospace; padding: 20px; max-width: 800px; margin: 0 auto; }
                h2 { border-bottom: 1px solid #ccc; padding-bottom: 5px; }
                .endpoint { background: #f4f4f4; padding: 10px; border-radius: 5px; margin-bottom: 20px; }
                .method { font-weight: bold; color: #007AFF; }
                .url { font-weight: bold; }
            </style>
        </head>
        <body>
            <h1>QvPlayer API</h1>
            
            <div class="endpoint">
                <span class="method">GET</span> <span class="url">/api/videos</span>
                <p>Get all videos in the playlist.</p>
            </div>
            
            <div class="endpoint">
                <span class="method">POST</span> <span class="url">/api/videos</span>
                <p>Add a new video.</p>
                <pre>
        {
          "title": "Channel Name",
          "url": "http://...",
          "group": "News"
        }
                </pre>
            </div>
            
            <div class="endpoint">
                <span class="method">DELETE</span> <span class="url">/api/videos?index={index}</span>
                <p>Delete a video by index.</p>
            </div>
            
            <div class="endpoint">
                <span class="method">PUT</span> <span class="url">/api/videos?index={index}</span>
                <p>Update a video by index.</p>
                <pre>
        {
          "title": "New Name",
          "url": "http://...",
          "group": "New Group"
        }
                </pre>
            </div>
            
            <div class="endpoint">
                <span class="method">POST</span> <span class="url">/api/playlist</span>
                <p>Replace the entire playlist.</p>
                <pre>
        {
          "content": "#EXTM3U..."
        }
                </pre>
            </div>
        </body>
        </html>
        """
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
