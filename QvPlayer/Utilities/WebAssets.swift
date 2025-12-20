import Foundation

struct WebAssets {
    static var htmlContent: String {
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
    
    static var apiDocsContent: String {
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
}
