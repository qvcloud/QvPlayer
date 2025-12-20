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
                :root {
                    --primary-color: #007AFF;
                    --bg-color: #f5f5f7;
                    --card-bg: #ffffff;
                    --text-color: #1d1d1f;
                    --secondary-text: #86868b;
                    --border-radius: 16px;
                    --shadow: 0 4px 12px rgba(0,0,0,0.05);
                }
                
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    background: var(--bg-color);
                    color: var(--text-color);
                    margin: 0;
                    padding: 20px;
                    line-height: 1.5;
                }
                
                .container { 
                    max-width: 1200px;
                    min-width: 1024px;
                    margin: 0 auto; 
                }
                
                .card {
                    background: var(--card-bg);
                    border-radius: var(--border-radius);
                    padding: 24px;
                    margin-bottom: 20px;
                    box-shadow: var(--shadow);
                }
                
                h1 { 
                    font-size: 24px; 
                    margin: 0 0 20px 0; 
                    color: var(--text-color);
                }
                
                h2 { 
                    font-size: 18px; 
                    margin: 0 0 16px 0; 
                    color: var(--text-color);
                }
                
                /* Remote Control Grid */
                .remote-grid {
                    display: grid;
                    grid-template-columns: repeat(3, 1fr);
                    gap: 12px;
                    margin-top: 20px;
                }
                
                .control-btn {
                    background: #f2f2f7;
                    border: none;
                    border-radius: 12px;
                    padding: 16px;
                    font-size: 16px;
                    font-weight: 600;
                    color: var(--text-color);
                    cursor: pointer;
                    transition: all 0.2s ease;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 60px;
                }
                
                .control-btn:active {
                    transform: scale(0.96);
                    background: #e5e5ea;
                }
                
                .control-btn.primary {
                    background: var(--primary-color);
                    color: white;
                }
                
                .control-btn.large {
                    grid-column: span 3;
                }
                
                /* Status Display */
                .status-display {
                    background: #f2f2f7;
                    border-radius: 12px;
                    padding: 16px;
                    text-align: center;
                    margin-bottom: 20px;
                }
                
                .status-title {
                    font-size: 14px;
                    color: var(--secondary-text);
                    margin-bottom: 4px;
                }
                
                .status-value {
                    font-size: 18px;
                    font-weight: 600;
                    color: var(--text-color);
                    white-space: nowrap;
                    overflow: hidden;
                    text-overflow: ellipsis;
                }
                
                .time-display {
                    font-family: "SF Mono", SFMono-Regular, ui-monospace, monospace;
                    font-size: 24px;
                    font-weight: 700;
                    margin-top: 8px;
                    color: var(--primary-color);
                }
                
                /* Forms */
                input[type="text"], textarea {
                    width: 100%;
                    padding: 12px;
                    border: 1px solid #d2d2d7;
                    border-radius: 10px;
                    font-size: 16px;
                    margin-bottom: 12px;
                    box-sizing: border-box;
                    transition: border-color 0.2s;
                }
                
                input[type="text"]:focus, textarea:focus {
                    outline: none;
                    border-color: var(--primary-color);
                }
                
                .btn {
                    background: var(--primary-color);
                    color: white;
                    border: none;
                    padding: 12px 24px;
                    border-radius: 10px;
                    font-size: 16px;
                    font-weight: 600;
                    cursor: pointer;
                    width: 100%;
                    transition: opacity 0.2s;
                }
                
                .btn:hover { opacity: 0.9; }
                .btn.secondary { background: #e5e5ea; color: var(--text-color); }
                .btn.danger { background: #ff3b30; color: white; }
                
                /* Playlist */
                .video-list {
                    list-style: none;
                    padding: 0;
                    margin: 0;
                }
                
                .video-item {
                    padding: 16px 0;
                    border-bottom: 1px solid #e5e5ea;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                }
                
                .video-item:last-child { border-bottom: none; }
                
                .video-info { flex: 1; min-width: 0; margin-right: 16px; }
                
                .video-title {
                    font-weight: 600;
                    margin-bottom: 4px;
                    white-space: nowrap;
                    overflow: hidden;
                    text-overflow: ellipsis;
                }
                
                .video-meta {
                    font-size: 13px;
                    color: var(--secondary-text);
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }
                
                .badge {
                    background: #e5e5ea;
                    padding: 2px 8px;
                    border-radius: 4px;
                    font-size: 11px;
                    font-weight: 600;
                }
                
                .action-group {
                    display: flex;
                    gap: 8px;
                }
                
                .icon-btn {
                    background: none;
                    border: none;
                    padding: 8px;
                    cursor: pointer;
                    color: var(--primary-color);
                    border-radius: 8px;
                }
                
                .icon-btn:hover { background: #f2f2f7; }
                .icon-btn.danger { color: #ff3b30; }
                
                /* Modal */
                .modal {
                    display: none;
                    position: fixed;
                    top: 0; left: 0;
                    width: 100%; height: 100%;
                    background: rgba(0,0,0,0.4);
                    backdrop-filter: blur(4px);
                    align-items: center;
                    justify-content: center;
                    z-index: 1000;
                }
                
                .modal.active { display: flex; }
                
                .modal-content {
                    background: white;
                    padding: 24px;
                    border-radius: 20px;
                    width: 90%;
                    max-width: 400px;
                    box-shadow: 0 20px 40px rgba(0,0,0,0.2);
                }
                
                .modal-actions {
                    display: flex;
                    gap: 12px;
                    margin-top: 20px;
                }
                
                /* Tabs */
                .tabs {
                    display: flex;
                    gap: 10px;
                    margin-bottom: 20px;
                    overflow-x: auto;
                    padding-bottom: 4px;
                }
                
                .tab-btn {
                    background: none;
                    border: none;
                    padding: 8px 16px;
                    font-size: 15px;
                    font-weight: 600;
                    color: var(--secondary-text);
                    cursor: pointer;
                    border-radius: 20px;
                    white-space: nowrap;
                }
                
                .tab-btn.active {
                    background: var(--text-color);
                    color: white;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="card">
                    <div class="status-display">
                        <div class="status-title">NOW PLAYING</div>
                        <div class="status-value" id="nowPlayingText">-</div>
                        <div class="time-display" id="timeText">00:00</div>
                        <div id="statusText" style="font-size: 12px; margin-top: 4px; color: var(--secondary-text);">Idle</div>
                    </div>
                    
                    <div class="remote-grid">
                        <button class="control-btn" onclick="control('seek', -15)">
                            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M11 17l-5-5 5-5M18 17l-5-5 5-5"/>
                            </svg>
                            <span style="margin-left: 4px">15s</span>
                        </button>
                        <button class="control-btn primary" onclick="control('toggle')" id="playPauseBtn">
                            <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
                                <path d="M8 5v14l11-7z"/>
                            </svg>
                        </button>
                        <button class="control-btn" onclick="control('seek', 15)">
                            <span style="margin-right: 4px">15s</span>
                            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M13 17l5-5-5-5M6 17l5-5-5-5"/>
                            </svg>
                        </button>
                    </div>
                </div>
                
                <div class="tabs">
                    <button class="tab-btn active" onclick="switchTab('playlist')">Playlist</button>
                    <button class="tab-btn" onclick="switchTab('add')">Add Stream</button>
                    <button class="tab-btn" onclick="switchTab('upload')">Upload</button>
                    <button class="tab-btn" onclick="switchTab('settings')">Settings</button>
                </div>
                
                <div id="tab-playlist" class="tab-content">
                    <div class="card">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
                            <h2>Library</h2>
                            <button class="icon-btn" onclick="loadPlaylist()">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <path d="M23 4v6h-6M1 20v-6h6"/>
                                    <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>
                                </svg>
                            </button>
                        </div>
                        <ul id="playlist" class="video-list">
                            <!-- Items loaded via JS -->
                        </ul>
                    </div>
                </div>
                
                <div id="tab-add" class="tab-content" style="display: none;">
                    <div class="card">
                        <h2>Add New Stream</h2>
                        <form id="addForm" onsubmit="handleAddStream(event)">
                            <input type="text" name="title" placeholder="Channel Name (e.g. CCTV-1)" required>
                            <input type="text" name="group" placeholder="Group (Optional)">
                            <input type="text" name="url" placeholder="Stream URL (m3u8/mp4)" required>
                            <button type="submit" class="btn">Add to Library</button>
                        </form>
                    </div>
                </div>
                
                <div id="tab-upload" class="tab-content" style="display: none;">
                    <div class="card">
                        <h2>Upload Local File</h2>
                        <div style="border: 2px dashed #d2d2d7; border-radius: 12px; padding: 40px; text-align: center; margin-bottom: 16px;">
                            <input type="file" id="fileInput" style="display: none" onchange="handleFileSelect()">
                            <button class="btn secondary" onclick="document.getElementById('fileInput').click()">Select Video File</button>
                            <div id="fileName" style="margin-top: 12px; color: var(--secondary-text);"></div>
                        </div>
                        <button onclick="uploadFile()" class="btn" id="uploadBtn" disabled>Upload & Play</button>
                        <div id="uploadStatus" style="margin-top: 12px; text-align: center; font-size: 14px;"></div>
                    </div>
                </div>
                
                <div id="tab-settings" class="tab-content" style="display: none;">
                    <div class="card">
                        <h2>Replace Playlist</h2>
                        <p style="color: var(--secondary-text); font-size: 14px; margin-bottom: 12px;">Paste M3U content to overwrite entire library.</p>
                        <form id="replaceForm" onsubmit="handleReplacePlaylist(event)">
                            <textarea name="content" style="height: 150px;" placeholder="#EXTM3U..."></textarea>
                            <button type="submit" class="btn danger">Replace All</button>
                        </form>
                    </div>
                </div>
            </div>
            
            <!-- Edit Modal -->
            <div id="editModal" class="modal">
                <div class="modal-content">
                    <h2>Edit Stream</h2>
                    <input type="hidden" id="editIndex">
                    <input type="text" id="editTitle" placeholder="Name">
                    <input type="text" id="editGroup" placeholder="Group">
                    <input type="text" id="editUrl" placeholder="URL">
                    <div class="modal-actions">
                        <button onclick="closeModal()" class="btn secondary">Cancel</button>
                        <button onclick="saveEdit()" class="btn">Save</button>
                    </div>
                </div>
            </div>

            <script>
                let currentVideos = [];
                
                function switchTab(tabId) {
                    document.querySelectorAll('.tab-content').forEach(el => el.style.display = 'none');
                    document.getElementById('tab-' + tabId).style.display = 'block';
                    document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
                    event.target.classList.add('active');
                }

                function control(action, time) {
                    let url = '/api/v1/control/' + action;
                    if (time) url += '?time=' + time;
                    fetch(url, { method: 'POST' });
                    
                    // Optimistic UI update
                    if (action === 'toggle') {
                        const btn = document.getElementById('playPauseBtn');
                        // Toggle icon logic would go here based on real state
                    }
                }
                
                function handleAddStream(e) {
                    e.preventDefault();
                    const formData = new FormData(e.target);
                    const data = Object.fromEntries(formData.entries());
                    
                    fetch('/api/v1/videos', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify(data)
                    })
                    .then(res => res.json())
                    .then(res => {
                        if(res.success) {
                            e.target.reset();
                            switchTab('playlist');
                            loadPlaylist();
                        }
                    });
                }
                
                function handleReplacePlaylist(e) {
                    e.preventDefault();
                    if(!confirm('This will delete all existing channels. Continue?')) return;
                    
                    const formData = new FormData(e.target);
                    const content = formData.get('content');
                    
                    fetch('/api/v1/playlist', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({ content })
                    })
                    .then(res => res.json())
                    .then(res => {
                        if(res.success) {
                            e.target.reset();
                            switchTab('playlist');
                            loadPlaylist();
                        }
                    });
                }
                
                function handleFileSelect() {
                    const file = document.getElementById('fileInput').files[0];
                    if (file) {
                        document.getElementById('fileName').textContent = file.name;
                        document.getElementById('uploadBtn').disabled = false;
                    }
                }
                
                function uploadFile() {
                    const file = document.getElementById('fileInput').files[0];
                    if (!file) return;
                    
                    const formData = new FormData();
                    formData.append('file', file);
                    
                    const statusDiv = document.getElementById('uploadStatus');
                    const btn = document.getElementById('uploadBtn');
                    
                    statusDiv.textContent = 'Uploading...';
                    btn.disabled = true;
                    btn.textContent = 'Uploading...';
                    
                    fetch('/api/v1/upload', {
                        method: 'POST',
                        body: formData
                    })
                    .then(res => res.json())
                    .then(data => {
                        btn.disabled = false;
                        btn.textContent = 'Upload & Play';
                        if (data.success) {
                            statusDiv.textContent = 'Success!';
                            document.getElementById('fileInput').value = '';
                            document.getElementById('fileName').textContent = '';
                            switchTab('playlist');
                            loadPlaylist();
                        } else {
                            statusDiv.textContent = 'Error: ' + (data.error || 'Unknown');
                        }
                    })
                    .catch(err => {
                        btn.disabled = false;
                        statusDiv.textContent = 'Error: ' + err;
                    });
                }
                
                function truncateMiddle(text, maxLength) {
                    if (!text) return '';
                    if (text.length <= maxLength) return text;
                    const partLength = Math.floor((maxLength - 3) / 2);
                    return text.substring(0, partLength) + '...' + text.substring(text.length - partLength);
                }

                function loadPlaylist() {
                    fetch('/api/v1/playlist')
                        .then(res => res.json())
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
                                        <div class="video-meta">
                                            <span class="badge">${escapeHtml(video.group || 'Default')}</span>
                                            <span style="opacity: 0.6; font-family: monospace; font-size: 11px;">${escapeHtml(truncateMiddle(video.url, 40))}</span>
                                        </div>
                                    </div>
                                    <div class="action-group">
                                        <button class="icon-btn" onclick="playVideo(${index})" title="Play">
                                            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                                        </button>
                                        <button class="icon-btn" onclick="openEdit(${index})" title="Edit">
                                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                                        </button>
                                        <button class="icon-btn danger" onclick="deleteVideo(${index})" title="Delete">
                                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                                        </button>
                                    </div>
                                `;
                                list.appendChild(li);
                            });
                        });
                }
                
                function playVideo(index) {
                    fetch('/api/v1/control/play_video?index=' + index, { method: 'POST' });
                }
                
                function deleteVideo(index) {
                    if(confirm('Delete this stream?')) {
                        fetch('/api/v1/videos?index=' + index, { method: 'DELETE' })
                            .then(() => loadPlaylist());
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
                    const data = {
                        title: document.getElementById('editTitle').value,
                        group: document.getElementById('editGroup').value,
                        url: document.getElementById('editUrl').value
                    };
                    
                    fetch('/api/v1/videos?index=' + index, {
                        method: 'PUT',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify(data)
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
                    fetch('/api/v1/status')
                        .then(res => res.json())
                        .then(data => {
                            document.getElementById('nowPlayingText').textContent = data.title || 'Not Playing';
                            document.getElementById('statusText').textContent = data.isPlaying ? 'Playing' : 'Paused';
                            
                            const formatTime = (s) => {
                                if (!s) return '00:00';
                                const m = Math.floor(s / 60);
                                const sec = Math.floor(s % 60);
                                return `${m.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`;
                            };
                            document.getElementById('timeText').textContent = 
                                `${formatTime(data.currentTime)} / ${formatTime(data.duration)}`;
                                
                            // Update Play/Pause Button Icon
                            const btn = document.getElementById('playPauseBtn');
                            if(data.isPlaying) {
                                btn.innerHTML = '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>';
                            } else {
                                btn.innerHTML = '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>';
                            }
                        })
                        .catch(console.error);
                }
                
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
                <span class="method">GET</span> <span class="url">/api/v1/videos</span>
                <p>Get all videos in the playlist.</p>
            </div>
            
            <div class="endpoint">
                <span class="method">POST</span> <span class="url">/api/v1/videos</span>
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
                <span class="method">DELETE</span> <span class="url">/api/v1/videos?index={index}</span>
                <p>Delete a video by index.</p>
            </div>
            
            <div class="endpoint">
                <span class="method">PUT</span> <span class="url">/api/v1/videos?index={index}</span>
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
                <span class="method">POST</span> <span class="url">/api/v1/playlist</span>
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
