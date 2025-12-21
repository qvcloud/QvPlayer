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
                                .badge.live { background: #34c759; color: white; }
                .badge.local { background: #007aff; color: white; }
                .badge.latency-good { background: #34c759; color: white; }
                .badge.latency-medium { background: #ff9500; color: white; }
                .badge.latency-bad { background: #ff3b30; color: white; }
                
                .filter-group { display: flex; background: #f2f2f7; padding: 2px; border-radius: 8px; margin-right: 12px; }
                .filter-btn { padding: 4px 12px; border: none; background: none; border-radius: 6px; font-size: 13px; cursor: pointer; color: var(--text-color); }
                .filter-btn.active { background: white; box-shadow: 0 1px 3px rgba(0,0,0,0.1); font-weight: 500; }
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
                        <div id="connectionInfo" style="font-size: 11px; margin-top: 8px; padding-top: 8px; border-top: 1px solid #e5e5ea; display: none;">
                            <div style="display: flex; justify-content: space-between; margin-bottom: 2px;">
                                <span style="color: var(--secondary-text);">Server:</span>
                                <span id="serverAddress" style="font-family: monospace;">-</span>
                            </div>
                            <div style="display: flex; justify-content: space-between;">
                                <span style="color: var(--secondary-text);">Status:</span>
                                <span id="onlineStatus">-</span>
                            </div>
                        </div>
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
                </div>
                
                <div id="tab-playlist" class="tab-content">
                    <div class="card">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
                            <h2>Library</h2>
                            <div class="filter-group">
                                <button class="filter-btn active" id="filter-all" onclick="setFilter('all')">All</button>
                                <button class="filter-btn" id="filter-local" onclick="setFilter('local')">Local</button>
                                <button class="filter-btn" id="filter-live" onclick="setFilter('live')">Live</button>
                            </div>
                            <div style="display: flex; gap: 8px;">
                                <div id="batchToolbar" style="display: none; gap: 8px;">
                                    <button class="btn secondary" onclick="openBatchMoveModal()">Move Selected</button>
                                    <button class="btn danger" onclick="batchDelete()">Delete Selected</button>
                                </div>
                                <button class="icon-btn" onclick="loadPlaylist()">
                                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                        <path d="M23 4v6h-6M1 20v-6h6"/>
                                        <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>
                                    </svg>
                                </button>
                            </div>
                        </div>
                        <div style="padding: 8px 16px; border-bottom: 1px solid #e5e5ea; display: flex; align-items: center;">
                            <input type="checkbox" id="selectAll" onchange="toggleSelectAll(this)" style="margin-right: 12px;">
                            <label for="selectAll" style="font-size: 14px; color: var(--secondary-text); margin-right: 16px;">Select All</label>
                            <select id="groupFilter" onchange="renderPlaylist()" style="padding: 4px 8px; border-radius: 6px; border: 1px solid #d2d2d7; background: white; font-size: 13px; color: var(--text-color); cursor: pointer;">
                                <option value="all">All Groups</option>
                            </select>
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
                        <h2>Add Remote Source</h2>
                        <p style="color: var(--secondary-text); font-size: 14px; margin-bottom: 12px;">Enter a URL to a remote M3U/M3U8 playlist.</p>
                        <div style="display: flex; flex-direction: column; gap: 10px; margin-bottom: 12px;">
                            <input type="text" id="remoteUrl" placeholder="https://example.com/playlist.m3u" style="padding: 10px; border-radius: 8px; border: 1px solid #d2d2d7;">
                            <input type="text" id="remoteName" placeholder="Group Name (Optional)" style="padding: 10px; border-radius: 8px; border: 1px solid #d2d2d7;">
                        </div>
                        <button onclick="addRemoteSource()" class="btn" id="addRemoteBtn">Add Source</button>
                        <div id="remoteStatus" style="margin-top: 12px; text-align: center; font-size: 14px;"></div>
                    </div>

                    <div class="card">
                        <h2>Upload Local File</h2>
                        <div style="border: 2px dashed #d2d2d7; border-radius: 12px; padding: 40px; text-align: center; margin-bottom: 16px;">
                            <input type="file" id="fileInput" style="display: none" onchange="handleFileSelect()">
                            <button class="btn secondary" onclick="document.getElementById('fileInput').click()">Select Video File</button>
                            <div id="fileName" style="margin-top: 12px; color: var(--secondary-text);"></div>
                        </div>
                        <input type="text" id="uploadGroup" placeholder="Group Name (Optional)" style="margin-bottom: 16px;">
                        <button onclick="uploadFile()" class="btn" id="uploadBtn" disabled>Upload & Play</button>
                        <div id="uploadStatus" style="margin-top: 12px; text-align: center; font-size: 14px;"></div>
                    </div>
                </div>

                <footer style="text-align: center; margin-top: 40px; padding-bottom: 20px; color: var(--secondary-text); font-size: 14px;">
                    <p>&copy; <span id="year"></span> QvPlayer. All rights reserved.</p>
                    <p>Open Source: <a href="https://github.com/qvcloud/QvPlayer" target="_blank" style="color: var(--primary-color); text-decoration: none;">https://github.com/qvcloud/QvPlayer</a></p>
                    <p>Telegram: <a href="https://t.me/+KF2GIXtuEOY3MWI1" target="_blank" style="color: var(--primary-color); text-decoration: none;">https://t.me/+KF2GIXtuEOY3MWI1</a></p>
                    <script>document.getElementById('year').textContent = new Date().getFullYear();</script>
                </footer>
            </div>
            
            <!-- Edit Modal -->
            <div id="editModal" class="modal">
                <div class="modal-content">
                    <h2>Edit Stream</h2>
                    <input type="hidden" id="editIndex">
                    <input type="text" id="editTitle" placeholder="Name">
                    <input type="text" id="editGroup" placeholder="Group">
                    <input type="text" id="editUrl" placeholder="URL" disabled>
                    <div class="modal-actions">
                        <button onclick="closeModal()" class="btn secondary">Cancel</button>
                        <button onclick="saveEdit()" class="btn">Save</button>
                    </div>
                </div>
            </div>
            
            <!-- Batch Move Modal -->
            <div id="batchMoveModal" class="modal">
                <div class="modal-content">
                    <h2>Move Selected to Group</h2>
                    <input type="text" id="batchGroupInput" placeholder="New Group Name">
                    <div class="modal-actions">
                        <button onclick="closeBatchMoveModal()" class="btn secondary">Cancel</button>
                        <button onclick="batchMove()" class="btn">Move</button>
                    </div>
                </div>
            </div>

            <script>
                let currentVideos = [];
                let selectedIndices = new Set();
                
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
                    
                    const group = document.getElementById('uploadGroup').value.trim();
                    
                    const formData = new FormData();
                    formData.append('file', file);
                    if (group) {
                        formData.append('group', group);
                    }
                    
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

                function addRemoteSource() {
                    const urlInput = document.getElementById('remoteUrl');
                    const nameInput = document.getElementById('remoteName');
                    const url = urlInput.value.trim();
                    const name = nameInput.value.trim();
                    
                    if (!url) {
                        alert('Please enter a URL');
                        return;
                    }
                    
                    const statusDiv = document.getElementById('remoteStatus');
                    const btn = document.getElementById('addRemoteBtn');
                    
                    statusDiv.textContent = 'Adding source...';
                    btn.disabled = true;
                    
                    fetch('/api/v1/upload/remote', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            url: url,
                            name: name || null
                        })
                    })
                    .then(res => res.json())
                    .then(data => {
                        btn.disabled = false;
                        if (data.success) {
                            statusDiv.textContent = 'Success!';
                            urlInput.value = '';
                            nameInput.value = '';
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

                let currentFilter = 'all';

                function setFilter(filter) {
                    currentFilter = filter;
                    document.querySelectorAll('.filter-btn').forEach(btn => btn.classList.remove('active'));
                    document.getElementById('filter-' + filter).classList.add('active');
                    document.getElementById('selectAll').checked = false;
                    renderPlaylist();
                }

                function updateGroupFilter() {
                    const select = document.getElementById('groupFilter');
                    const currentSelection = select.value;
                    
                    // Get unique groups
                    const groups = new Set();
                    currentVideos.forEach(v => {
                        if (v.group) groups.add(v.group);
                    });
                    
                    // Save current selection if it still exists, otherwise default to 'all'
                    const shouldKeepSelection = groups.has(currentSelection);
                    
                    select.innerHTML = '<option value="all">All Groups</option>';
                    
                    Array.from(groups).sort().forEach(group => {
                        const option = document.createElement('option');
                        option.value = group;
                        option.textContent = group;
                        select.appendChild(option);
                    });
                    
                    if (shouldKeepSelection) {
                        select.value = currentSelection;
                    }
                }

                function loadPlaylist() {
                    fetch('/api/v1/playlist')
                        .then(res => res.json())
                        .then(data => {
                            if (!Array.isArray(data)) {
                                console.error('Playlist data is not an array:', data);
                                return;
                            }
                            currentVideos = data;
                            selectedIndices.clear();
                            updateBatchToolbar();
                            updateGroupFilter();
                            document.getElementById('selectAll').checked = false;
                            renderPlaylist();
                        })
                        .catch(err => console.error('Failed to load playlist:', err));
                }

                function renderPlaylist() {
                    const list = document.getElementById('playlist');
                    list.innerHTML = '';
                    
                    const groupFilter = document.getElementById('groupFilter').value;
                    
                    currentVideos.forEach((video, index) => {
                        // Robust check for isLive
                        const isLive = video.isLive === true;
                        
                        if (currentFilter === 'local' && isLive) return;
                        if (currentFilter === 'live' && !isLive) return;
                        
                        if (groupFilter !== 'all' && video.group !== groupFilter) return;
                        
                        const isSelected = selectedIndices.has(index);
                        const typeBadge = isLive 
                            ? '<span class="badge live">LIVE</span>' 
                            : '<span class="badge local">LOCAL</span>';
                        
                        let latencyBadge = '';
                        if (isLive && video.latency !== undefined) {
                            const latency = video.latency;
                            if (latency < 0) {
                                latencyBadge = '<span class="badge latency-bad">Timeout</span>';
                            } else if (latency < 200) {
                                latencyBadge = `<span class="badge latency-good">${Math.round(latency)}ms</span>`;
                            } else if (latency < 500) {
                                latencyBadge = `<span class="badge latency-medium">${Math.round(latency)}ms</span>`;
                            } else {
                                latencyBadge = `<span class="badge latency-bad">${Math.round(latency)}ms</span>`;
                            }
                        }
                            
                        const li = document.createElement('li');
                        li.className = 'video-item';
                        li.innerHTML = `
                            <div style="display: flex; align-items: center; gap: 12px; flex: 1;">
                                <input type="checkbox" class="video-checkbox" data-index="${index}" onchange="toggleSelection(${index}, this)" ${isSelected ? 'checked' : ''}>
                                <div class="video-info">
                                    <div class="video-title">${escapeHtml(video.title)}</div>
                                    <div class="video-meta">
                                        ${typeBadge}
                                        ${latencyBadge}
                                        <span class="badge">${escapeHtml(video.group || 'Default')}</span>
                                        <span style="opacity: 0.6; font-family: monospace; font-size: 11px;">${escapeHtml(truncateMiddle(video.url, 40))}</span>
                                    </div>
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
                }
                
                function toggleSelection(index, checkbox) {
                    if (checkbox.checked) {
                        selectedIndices.add(index);
                    } else {
                        selectedIndices.delete(index);
                    }
                    updateBatchToolbar();
                }
                
                function toggleSelectAll(checkbox) {
                    const checkboxes = document.querySelectorAll('.video-checkbox');
                    checkboxes.forEach(cb => {
                        cb.checked = checkbox.checked;
                        const index = parseInt(cb.getAttribute('data-index'));
                        if (checkbox.checked) {
                            selectedIndices.add(index);
                        } else {
                            selectedIndices.delete(index);
                        }
                    });
                    updateBatchToolbar();
                }
                
                function updateBatchToolbar() {
                    const toolbar = document.getElementById('batchToolbar');
                    if (selectedIndices.size > 0) {
                        toolbar.style.display = 'flex';
                    } else {
                        toolbar.style.display = 'none';
                    }
                }
                
                function batchDelete() {
                    if (!confirm(`Delete ${selectedIndices.size} selected items?`)) return;
                    
                    fetch('/api/v1/videos/batch', {
                        method: 'DELETE',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({ indices: Array.from(selectedIndices) })
                    })
                    .then(res => res.json())
                    .then(res => {
                        if (res.success) {
                            loadPlaylist();
                        } else {
                            alert('Error: ' + (res.error || 'Unknown'));
                        }
                    });
                }
                
                function openBatchMoveModal() {
                    document.getElementById('batchMoveModal').classList.add('active');
                }
                
                function closeBatchMoveModal() {
                    document.getElementById('batchMoveModal').classList.remove('active');
                }
                
                function batchMove() {
                    const group = document.getElementById('batchGroupInput').value;
                    fetch('/api/v1/videos/batch/group', {
                        method: 'PUT',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({ 
                            indices: Array.from(selectedIndices),
                            group: group
                        })
                    })
                    .then(res => res.json())
                    .then(res => {
                        if (res.success) {
                            closeBatchMoveModal();
                            loadPlaylist();
                        } else {
                            alert('Error: ' + (res.error || 'Unknown'));
                        }
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
                                
                            // Update Connection Info
                            const connInfo = document.getElementById('connectionInfo');
                            if (data.serverAddress && data.serverAddress !== '-') {
                                connInfo.style.display = 'block';
                                document.getElementById('serverAddress').textContent = data.serverAddress;
                                
                                const statusSpan = document.getElementById('onlineStatus');
                                const isOnline = data.isOnline === true;
                                statusSpan.textContent = isOnline ? 'Online' : 'Offline';
                                statusSpan.style.color = isOnline ? '#34c759' : '#ff3b30';
                                statusSpan.style.fontWeight = '600';
                            } else {
                                connInfo.style.display = 'none';
                            }
                                
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
