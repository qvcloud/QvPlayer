import Foundation
import Network

class WebServer {
    static let shared = WebServer()
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 8080
    
    var serverURL: String? {
        if let ip = getIPAddress() {
            return "http://\(ip):\(port)"
        }
        return nil
    }
    
    func start() {
        do {
            listener = try NWListener(using: .tcp, on: port)
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("Server ready on port \(self.port)")
                case .failed(let error):
                    print("Server failed with error: \(error)")
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { newConnection in
                self.handleConnection(newConnection)
            }
            
            listener?.start(queue: .global())
        } catch {
            print("Failed to create listener: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())
        receive(on: connection)
    }
    
    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, context, isComplete, error) in
            if let data = data, !data.isEmpty {
                self?.processRequest(data: data, connection: connection)
            }
            if error != nil {
                connection.cancel()
            }
        }
    }
    
    private func processRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            connection.cancel()
            return
        }
        
        // Simple parsing
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return }
        let parts = requestLine.components(separatedBy: " ")
        
        guard parts.count >= 2 else { return }
        let method = parts[0]
        let path = parts[1]
        
        if method == "GET" && path == "/" {
            sendResponse(connection: connection, body: htmlContent)
        } else if method == "GET" && path == "/api/playlist" {
            let videos = PlaylistManager.shared.getPlaylistVideos()
            let jsonItems = videos.map { ["title": $0.title, "url": $0.url.absoluteString] }
            if let data = try? JSONSerialization.data(withJSONObject: jsonItems),
               let jsonString = String(data: data, encoding: .utf8) {
                sendResponse(connection: connection, contentType: "application/json", body: jsonString)
            } else {
                sendResponse(connection: connection, status: "500 Internal Server Error", body: "{}")
            }
        } else if method == "POST" && path == "/api/delete" {
            if let range = requestString.range(of: "\r\n\r\n") {
                let body = String(requestString[range.upperBound...])
                let params = parseParams(body)
                if let indexStr = params["index"], let index = Int(indexStr) {
                    PlaylistManager.shared.deleteVideo(at: index)
                    sendResponse(connection: connection, contentType: "application/json", body: "{\"success\": true}")
                } else {
                    sendResponse(connection: connection, status: "400 Bad Request", body: "Missing index")
                }
            }
        } else if method == "POST" && path == "/api/edit" {
            if let range = requestString.range(of: "\r\n\r\n") {
                let body = String(requestString[range.upperBound...])
                let params = parseParams(body)
                if let indexStr = params["index"], let index = Int(indexStr),
                   let title = params["title"], let url = params["url"] {
                    PlaylistManager.shared.updateVideo(at: index, title: title, url: url)
                    sendResponse(connection: connection, contentType: "application/json", body: "{\"success\": true}")
                } else {
                    sendResponse(connection: connection, status: "400 Bad Request", body: "Missing parameters")
                }
            }
        } else if method == "POST" && path == "/update" {
            // Extract body
            if let range = requestString.range(of: "\r\n\r\n") {
                let body = String(requestString[range.upperBound...])
                let decodedBody = body.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? body
                
                var m3uContent = decodedBody
                if decodedBody.hasPrefix("playlist=") {
                    m3uContent = String(decodedBody.dropFirst(9))
                }
                
                PlaylistManager.shared.savePlaylist(content: m3uContent)
                let successPage = "<html><body><h1>Playlist Replaced!</h1><a href='/'>Back</a></body></html>"
                sendResponse(connection: connection, body: successPage)
            }
        } else if method == "POST" && path == "/add" {
            if let range = requestString.range(of: "\r\n\r\n") {
                let body = String(requestString[range.upperBound...])
                let params = parseParams(body)
                
                if let title = params["title"], let url = params["url"] {
                    PlaylistManager.shared.appendVideo(title: title, url: url)
                    let successPage = "<html><body><h1>Stream Added!</h1><a href='/'>Back</a></body></html>"
                    sendResponse(connection: connection, body: successPage)
                } else {
                    sendResponse(connection: connection, status: "400 Bad Request", body: "Missing title or url")
                }
            }
        } else {
            sendResponse(connection: connection, status: "404 Not Found", body: "Not Found")
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
    
    private func sendResponse(connection: NWConnection, status: String = "200 OK", contentType: String = "text/html", body: String) {
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
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
                
                <h2>Add Stream</h2>
                <form action="/add" method="POST">
                    <label>Channel Name</label>
                    <input type="text" name="title" placeholder="e.g. CCTV-1" required>
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
                                        <div class="video-title">${escapeHtml(video.title)}</div>
                                        <div class="video-url">${escapeHtml(video.url)}</div>
                                    </div>
                                    <div class="video-actions">
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
                    document.getElementById('editUrl').value = video.url;
                    document.getElementById('editModal').classList.add('active');
                }
                
                function closeModal() {
                    document.getElementById('editModal').classList.remove('active');
                }
                
                function saveEdit() {
                    const index = document.getElementById('editIndex').value;
                    const title = document.getElementById('editTitle').value;
                    const url = document.getElementById('editUrl').value;
                    
                    fetch('/api/edit', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                        body: `index=${index}&title=${encodeURIComponent(title)}&url=${encodeURIComponent(url)}`
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
                
                loadPlaylist();
            </script>
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
                
                guard let interface = ptr?.pointee else { return nil }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" { // Usually WiFi
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}
