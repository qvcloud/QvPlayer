import Foundation

struct WebAssets {
    static var htmlContent: String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
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
                    padding: 0;
                    line-height: 1.5;
                    height: 100vh;
                    overflow: hidden;
                }
                
                .container { 
                    display: flex;
                    height: 100%;
                    width: 100%;
                    max-width: none;
                    margin: 0;
                }
                
                .sidebar {
                    width: 320px;
                    background: #fff;
                    border-right: 1px solid #d2d2d7;
                    display: flex;
                    flex-direction: column;
                    padding: 0;
                    box-sizing: border-box;
                    flex-shrink: 0;
                    z-index: 10;
                }
                
                .sidebar-header {
                    padding: 20px;
                    border-bottom: 1px solid #e5e5ea;
                    background: rgba(255,255,255,0.95);
                    backdrop-filter: blur(10px);
                }
                
                .sidebar-content {
                    flex: 1;
                    overflow-y: auto;
                    padding: 0;
                }
                
                .main-content {
                    flex: 1;
                    padding: 20px;
                    overflow-y: auto;
                    background: var(--bg-color);
                    min-width: 0; /* Prevent flex overflow */
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

                /* Pagination */
                .pagination {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    gap: 8px;
                    margin-top: 20px;
                    padding-top: 20px;
                    border-top: 1px solid #e5e5ea;
                }
                
                .page-btn {
                    background: white;
                    border: 1px solid #d2d2d7;
                    padding: 6px 12px;
                    border-radius: 6px;
                    cursor: pointer;
                    font-size: 14px;
                    color: var(--text-color);
                }
                
                .page-btn:disabled {
                    opacity: 0.5;
                    cursor: not-allowed;
                }
                
                .page-btn.active {
                    background: var(--primary-color);
                    color: white;
                    border-color: var(--primary-color);
                }
            </style>
        </head>
        <body>
            <div class="container">
                <!-- Sidebar -->
                <div class="sidebar">
                    <div class="sidebar-header">
                        <h2 style="margin-bottom: 12px;">Playlist Queue</h2>
                        <div style="display: flex; align-items: center; justify-content: space-between; font-size: 13px; color: var(--secondary-text);">
                            <label style="display: flex; align-items: center; cursor: pointer; color: var(--text-color);">
                                <input type="checkbox" id="loopMedia" onchange="toggleLoop(this)" style="margin-right: 8px; width: auto; margin-bottom: 0;"> Loop Playback
                            </label>
                            <span id="mediaCount">0 items</span>
                        </div>
                    </div>
                    <div class="sidebar-content">
                        <ul id="sidebarList" class="video-list" style="padding: 0;">
                            <!-- Sidebar items -->
                        </ul>
                    </div>
                </div>

                <!-- Main Content -->
                <div class="main-content">
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
                    <button class="tab-btn active" onclick="switchTab('media')">Media</button>
                    <button class="tab-btn" onclick="switchTab('groups')">Groups</button>
                    <button class="tab-btn" onclick="switchTab('upload')">Upload</button>
                </div>
                
                <div id="tab-media" class="tab-content">
                    <div class="card">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
                            <div class="filter-group" style="align-items: center;">
                                <input type="text" id="searchInput" placeholder="Search..." oninput="handleSearch(this.value)" style="border: none; background: transparent; padding: 6px 12px; font-size: 13px; width: 150px; outline: none; margin-bottom: 0;">
                                <div style="width: 1px; height: 20px; background: #d2d2d7; margin: 0 4px;"></div>
                                <button class="filter-btn active" id="filter-all" onclick="setFilter('all')">All</button>
                                <button class="filter-btn" id="filter-local" onclick="setFilter('local')">Local</button>
                                <button class="filter-btn" id="filter-live" onclick="setFilter('live')">Live</button>
                            </div>
                            <div style="display: flex; gap: 8px;">
                                <div id="batchToolbar" style="display: none; gap: 8px;">
                                    <button class="btn secondary" onclick="openBatchMoveModal()">Move Selected</button>
                                    <button class="btn danger" onclick="batchDelete()">Delete Selected</button>
                                </div>
                                <button class="icon-btn" onclick="loadMedia()">
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
                            <select id="groupFilter" onchange="renderMedia()" style="padding: 4px 8px; border-radius: 6px; border: 1px solid #d2d2d7; background: white; font-size: 13px; color: var(--text-color); cursor: pointer;">
                                <option value="all">All Groups</option>
                            </select>
                        </div>
                        <ul id="mediaList" class="video-list">
                            <!-- Items loaded via JS -->
                        </ul>
                        <div id="pagination" class="pagination"></div>
                    </div>
                </div>
                
                <div id="tab-groups" class="tab-content" style="display: none;">
                    <div class="card">
                        <h2>Manage Groups</h2>
                        <p style="color: var(--secondary-text); font-size: 14px; margin-bottom: 16px;">Deleting a group will remove all videos and cache within it.</p>
                        <ul id="groupList" class="video-list">
                            <!-- Groups loaded via JS -->
                        </ul>
                    </div>
                </div>
                
                <div id="tab-upload" class="tab-content" style="display: none;">
                    <div class="card">
                        <h2>Add Live</h2>
                        <p style="color: var(--secondary-text); font-size: 14px; margin-bottom: 12px;">Enter a URL to a live stream (M3U8, etc).</p>
                        <div style="display: flex; flex-direction: column; gap: 10px; margin-bottom: 12px;">
                            <input type="text" id="liveUrl" placeholder="http://example.com/live.m3u8" style="padding: 10px; border-radius: 8px; border: 1px solid #d2d2d7;">
                            <input type="text" id="liveName" placeholder="Channel Name" style="padding: 10px; border-radius: 8px; border: 1px solid #d2d2d7;">
                            <input type="text" id="liveGroup" placeholder="Group Name (Optional)" style="padding: 10px; border-radius: 8px; border: 1px solid #d2d2d7;">
                        </div>
                        <button onclick="addLive()" class="btn" id="addLiveBtn">Add Live Channel</button>
                        <div id="liveStatus" style="margin-top: 12px; text-align: center; font-size: 14px;"></div>
                    </div>

                    <div class="card">
                        <h2>Add Remote File</h2>
                        <p style="color: var(--secondary-text); font-size: 14px; margin-bottom: 12px;">Enter a URL to a remote video file (MP4, MKV, etc).</p>
                        <div style="display: flex; flex-direction: column; gap: 10px; margin-bottom: 12px;">
                            <input type="text" id="remoteFileUrl" placeholder="http://example.com/video.mp4" style="padding: 10px; border-radius: 8px; border: 1px solid #d2d2d7;">
                            <input type="text" id="remoteFileName" placeholder="Video Name" style="padding: 10px; border-radius: 8px; border: 1px solid #d2d2d7;">
                            <input type="text" id="remoteFileGroup" placeholder="Group Name (Optional)" style="padding: 10px; border-radius: 8px; border: 1px solid #d2d2d7;">
                        </div>
                        <button onclick="addRemoteFile()" class="btn" id="addRemoteFileBtn">Add Remote File</button>
                        <div id="remoteFileStatus" style="margin-top: 12px; text-align: center; font-size: 14px;"></div>
                    </div>

                    <div class="card">
                        <h2>Upload Local File</h2>
                        <div style="border: 2px dashed #d2d2d7; border-radius: 12px; padding: 40px; text-align: center; margin-bottom: 16px;">
                            <input type="file" id="fileInput" style="display: none" multiple onchange="handleFileSelect()">
                            <button class="btn secondary" onclick="document.getElementById('fileInput').click()">Select Video Files</button>
                            <div id="fileName" style="margin-top: 12px; color: var(--secondary-text);"></div>
                        </div>
                        <input type="text" id="uploadGroup" placeholder="Group Name (Optional)" style="margin-bottom: 16px;">
                        <button onclick="uploadFile()" class="btn" id="uploadBtn" disabled>Upload</button>
                        <div id="uploadStatus" style="margin-top: 12px; text-align: center; font-size: 14px;"></div>
                    </div>
                </div>

                <footer style="text-align: center; margin-top: 40px; padding-bottom: 20px; color: var(--secondary-text); font-size: 14px;">
                    <p>&copy; <span id="year"></span> QvPlayer. All rights reserved.</p>
                    <p>Open Source: <a href="https://github.com/qvcloud/QvPlayer" target="_blank" style="color: var(--primary-color); text-decoration: none;">https://github.com/qvcloud/QvPlayer</a></p>
                    <p>Telegram: <a href="https://t.me/+KF2GIXtuEOY3MWI1" target="_blank" style="color: var(--primary-color); text-decoration: none;">https://t.me/+KF2GIXtuEOY3MWI1</a></p>
                    <script>document.getElementById('year').textContent = new Date().getFullYear();</script>
                </footer>
                </div> <!-- End Main Content -->
            </div> <!-- End Container -->
            
            <!-- Edit Modal -->
            <div id="editModal" class="modal">
                <div class="modal-content">
                    <h2>Edit Stream</h2>
                    <input type="hidden" id="editIndex">
                    <input type="text" id="editTitle" placeholder="Name">
                    <select id="editGroup" style="width: 100%; padding: 12px; border: 1px solid #d2d2d7; border-radius: 10px; font-size: 16px; margin-bottom: 12px; box-sizing: border-box; background: white;">
                        <!-- Options loaded via JS -->
                    </select>
                    <select id="editType" style="width: 100%; padding: 12px; border: 1px solid #d2d2d7; border-radius: 10px; font-size: 16px; margin-bottom: 12px; box-sizing: border-box; background: white;">
                        <option value="live">Live Stream</option>
                        <option value="local">Local / Remote File</option>
                    </select>
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
                    <select id="batchGroupInput" style="width: 100%; padding: 12px; border: 1px solid #d2d2d7; border-radius: 10px; font-size: 16px; margin-bottom: 12px; box-sizing: border-box; background: white;">
                        <!-- Options loaded via JS -->
                    </select>
                    <div class="modal-actions">
                        <button onclick="closeBatchMoveModal()" class="btn secondary">Cancel</button>
                        <button onclick="batchMove()" class="btn">Move</button>
                    </div>
                </div>
            </div>

            <script>
                let currentVideos = [];
                let currentQueue = [];
                let currentPlayingId = null;
                let selectedIndices = new Set();
                let currentPage = 1;
                const itemsPerPage = 20;
                let searchQuery = '';
                let loopEnabled = localStorage.getItem('loopEnabled') === 'true';
                
                // Initialize Loop Checkbox
                document.addEventListener('DOMContentLoaded', () => {
                    const cb = document.getElementById('loopPlaylist');
                    if(cb) cb.checked = loopEnabled;
                });

                function toggleLoop(cb) {
                    loopEnabled = cb.checked;
                    localStorage.setItem('loopEnabled', loopEnabled);
                }
                
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
                
                function handleSortOrderChange(index, newOrder) {
                    const order = parseInt(newOrder);
                    if (isNaN(order)) return;
                    
                    fetch('/api/v1/videos/sort', {
                        method: 'PUT',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({
                            index: index,
                            sortOrder: order
                        })
                    })
                    .then(res => res.json())
                    .then(res => {
                        if(res.success) {
                            loadMedia();
                        }
                    });
                }
                
                function handleFileSelect() {
                    const files = document.getElementById('fileInput').files;
                    if (files.length > 0) {
                        if (files.length === 1) {
                            document.getElementById('fileName').textContent = files[0].name;
                        } else {
                            document.getElementById('fileName').textContent = `${files.length} files selected`;
                        }
                        document.getElementById('uploadBtn').disabled = false;
                    }
                }
                
                function uploadFile() {
                    const files = document.getElementById('fileInput').files;
                    if (files.length === 0) return;
                    
                    const group = document.getElementById('uploadGroup').value.trim();
                    
                    const formData = new FormData();
                    for (let i = 0; i < files.length; i++) {
                        formData.append('files[]', files[i]);
                    }
                    
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
                            switchTab('media');
                            loadMedia();
                        } else {
                            statusDiv.textContent = 'Error: ' + (data.error || 'Unknown');
                        }
                    })
                    .catch(err => {
                        btn.disabled = false;
                        statusDiv.textContent = 'Error: ' + err;
                    });
                }

                function addLive() {
                    const urlInput = document.getElementById('liveUrl');
                    const nameInput = document.getElementById('liveName');
                    const groupInput = document.getElementById('liveGroup');
                    const url = urlInput.value.trim();
                    const name = nameInput.value.trim();
                    const group = groupInput.value.trim();
                    
                    if (!url || !name) {
                        alert('Please enter URL and Name');
                        return;
                    }
                    
                    const statusDiv = document.getElementById('liveStatus');
                    const btn = document.getElementById('addLiveBtn');
                    
                    statusDiv.textContent = 'Adding live channel...';
                    btn.disabled = true;
                    
                    fetch('/api/v1/videos', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            url: url,
                            title: name,
                            group: group || 'Live Sources',
                            isLive: true
                        })
                    })
                    .then(res => res.json())
                    .then(data => {
                        btn.disabled = false;
                        if (data.success) {
                            statusDiv.textContent = 'Success!';
                            urlInput.value = '';
                            nameInput.value = '';
                            groupInput.value = '';
                            switchTab('media');
                            loadMedia();
                        } else {
                            statusDiv.textContent = 'Error: ' + (data.error || 'Unknown');
                        }
                    })
                    .catch(err => {
                        btn.disabled = false;
                        statusDiv.textContent = 'Error: ' + err;
                    });
                }

                function addRemoteFile() {
                    const urlInput = document.getElementById('remoteFileUrl');
                    const nameInput = document.getElementById('remoteFileName');
                    const groupInput = document.getElementById('remoteFileGroup');
                    const url = urlInput.value.trim();
                    const name = nameInput.value.trim();
                    const group = groupInput.value.trim();
                    
                    if (!url || !name) {
                        alert('Please enter URL and Name');
                        return;
                    }
                    
                    const statusDiv = document.getElementById('remoteFileStatus');
                    const btn = document.getElementById('addRemoteFileBtn');
                    
                    statusDiv.textContent = 'Adding remote file...';
                    btn.disabled = true;
                    
                    fetch('/api/v1/videos', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            url: url,
                            title: name,
                            group: group || 'Remote Files',
                            isLive: false
                        })
                    })
                    .then(res => res.json())
                    .then(data => {
                        btn.disabled = false;
                        if (data.success) {
                            statusDiv.textContent = 'Success!';
                            urlInput.value = '';
                            nameInput.value = '';
                            groupInput.value = '';
                            switchTab('media');
                            loadMedia();
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
                    renderMedia();
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

                function loadMedia() {
                    fetch('/api/v1/media')
                        .then(res => res.json())
                        .then(data => {
                            if (!Array.isArray(data)) {
                                console.error('Media data is not an array:', data);
                                return;
                            }
                            currentVideos = data;
                            selectedIndices.clear();
                            updateBatchToolbar();
                            updateGroupFilter();
                            loadGroups();
                            document.getElementById('selectAll').checked = false;
                            currentPage = 1;
                            renderMedia();
                        })
                        .catch(err => console.error('Failed to load media:', err));
                }
                
                function renderSidebar() {
                    const list = document.getElementById('sidebarList');
                    list.innerHTML = '';
                    
                    // Show all items, sorted by sortOrder
                    const sortedQueue = [...currentQueue].sort((a, b) => a.sortOrder - b.sortOrder);
                    
                    sortedQueue.forEach((item, i) => {
                        const video = item.video;
                        if (!video) return;
                        
                        const li = document.createElement('li');
                        li.className = 'video-item sidebar-item';
                        li.style.padding = '10px 16px';
                        li.dataset.id = video.id;
                        li.dataset.queueId = item.id;
                        
                        // Styling based on status
                        if (item.status === 'playing') {
                            li.style.background = '#e3f2fd'; // Light blue for playing
                            li.style.borderLeft = '4px solid #2196f3';
                        } else if (item.status === 'played') {
                            li.style.opacity = '0.5';
                            li.style.background = '#f5f5f5'; // Gray for played
                            li.style.color = '#888';
                        }
                        
                        li.innerHTML = `
                            <div style="display: flex; align-items: center; gap: 8px; flex: 1; min-width: 0;">
                                <div style="color: #ccc; font-size: 12px; width: 20px;">${item.sortOrder}</div>
                                <div class="video-info" style="margin-right: 0;">
                                    <div class="video-title" style="font-size: 13px; margin-bottom: 2px;">${escapeHtml(video.title)}</div>
                                    <div class="video-meta" style="font-size: 11px;">${escapeHtml(video.group || 'Default')}</div>
                                </div>
                            </div>
                            ${item.status !== 'played' ? `
                            <button class="icon-btn" onclick="playQueueVideo('${video.id}')" style="padding: 4px;">
                                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                            </button>
                            ` : ''}
                        `;
                        list.appendChild(li);
                    });
                }
                
                function playQueueVideo(videoId) {
                    // Find index in main list to play
                    const index = currentVideos.findIndex(v => v.id === videoId);
                    if (index !== -1) {
                        playVideo(index);
                    }
                }
                
                function loadGroups() {
                    const groups = {};
                    currentVideos.forEach(v => {
                        const g = v.group || 'Default';
                        if (!groups[g]) groups[g] = 0;
                        groups[g]++;
                    });
                    
                    const list = document.getElementById('groupList');
                    list.innerHTML = '';
                    
                    Object.keys(groups).sort().forEach(group => {
                        const count = groups[group];
                        const li = document.createElement('li');
                        li.className = 'video-item';
                        li.innerHTML = `
                            <div class="video-info">
                                <div class="video-title">${escapeHtml(group)}</div>
                                <div class="video-meta">${count} videos</div>
                            </div>
                            <div class="action-group">
                                <button class="btn secondary" style="width: auto; padding: 8px 16px;" onclick="renameGroup('${escapeHtml(group)}')">Rename</button>
                                <button class="btn danger" style="width: auto; padding: 8px 16px;" onclick="deleteGroup('${escapeHtml(group)}')">Delete</button>
                            </div>
                        `;
                        list.appendChild(li);
                    });
                }
                
                function renameGroup(oldGroup) {
                    const newGroup = prompt("Enter new name for group '" + oldGroup + "':", oldGroup);
                    if (!newGroup || newGroup === oldGroup) return;
                    
                    const indices = [];
                    currentVideos.forEach((v, i) => {
                        if ((v.group || 'Default') === oldGroup) {
                            indices.push(i);
                        }
                    });
                    
                    fetch('/api/v1/videos/batch/group', {
                        method: 'PUT',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({ 
                            indices: indices,
                            group: newGroup
                        })
                    })
                    .then(res => res.json())
                    .then(res => {
                        if (res.success) {
                            loadMedia();
                        } else {
                            alert('Error: ' + (res.error || 'Unknown'));
                        }
                    });
                }
                
                function deleteGroup(group) {
                    if (!confirm(`Are you sure you want to delete group "${group}" and all its videos? This cannot be undone.`)) return;
                    
                    fetch('/api/v1/groups', {
                        method: 'DELETE',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({ group: group })
                    })
                    .then(res => res.json())
                    .then(res => {
                        if (res.success) {
                            loadMedia();
                        } else {
                            alert('Error: ' + (res.error || 'Unknown'));
                        }
                    });
                }

                function handleSearch(query) {
                    searchQuery = query.toLowerCase();
                    currentPage = 1;
                    renderMedia();
                }

                function setPage(page) {
                    currentPage = page;
                    renderMedia();
                }

                function renderMedia() {
                    const list = document.getElementById('mediaList');
                    list.innerHTML = '';
                    
                    const groupFilter = document.getElementById('groupFilter').value;
                    
                    // 1. Filter
                    let filteredVideos = currentVideos.map((v, i) => ({...v, originalIndex: i})).filter(video => {
                        // Search filter
                        if (searchQuery && !video.title.toLowerCase().includes(searchQuery)) return false;
                        
                        // Type filter
                        const isLive = video.isLive === true;
                        if (currentFilter === 'local' && isLive) return false;
                        if (currentFilter === 'live' && !isLive) return false;
                        
                        // Group filter
                        if (groupFilter !== 'all' && video.group !== groupFilter) return false;
                        
                        return true;
                    });
                    
                    // 2. Paginate
                    const totalPages = Math.ceil(filteredVideos.length / itemsPerPage);
                    if (currentPage > totalPages) currentPage = Math.max(1, totalPages);
                    
                    const start = (currentPage - 1) * itemsPerPage;
                    const end = start + itemsPerPage;
                    const pageVideos = filteredVideos.slice(start, end);
                    
                    // 3. Render Items
                    pageVideos.forEach(video => {
                        const index = video.originalIndex;
                        const isLive = video.isLive === true;
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
                        li.draggable = true;
                        li.dataset.index = index;
                        li.ondragstart = handleDragStart;
                        li.ondragover = handleDragOver;
                        li.ondrop = handleDrop;
                        
                        li.innerHTML = `
                            <div style="display: flex; align-items: center; gap: 12px; flex: 1;">
                                <div style="cursor: grab; color: #ccc; padding: 0 4px; display: flex; align-items: center;">
                                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                        <line x1="3" y1="12" x2="21" y2="12"></line>
                                        <line x1="3" y1="6" x2="21" y2="6"></line>
                                        <line x1="3" y1="18" x2="21" y2="18"></line>
                                    </svg>
                                </div>
                                <input type="checkbox" class="video-checkbox" data-index="${index}" onchange="toggleSelection(${index}, this)" ${isSelected ? 'checked' : ''}>
                                <div class="video-info">
                                    <div class="video-title">${escapeHtml(video.title)}</div>
                                    <div class="video-meta">
                                        ${typeBadge}
                                        ${latencyBadge}
                                        <span class="badge">${escapeHtml(video.group || 'Default')}</span>
                                        <div style="display: flex; align-items: center; gap: 4px;">
                                            <span style="font-size: 11px; color: #888;">Order:</span>
                                            <input type="number" 
                                                   value="${video.sortOrder || 0}" 
                                                   style="width: 60px; padding: 2px 4px; font-size: 11px; border: 1px solid #ddd; border-radius: 4px; margin: 0;"
                                                   onchange="handleSortOrderChange(${index}, this.value)"
                                                   onclick="event.stopPropagation()">
                                        </div>
                                        <span style="opacity: 0.6; font-family: monospace; font-size: 11px;">${escapeHtml(truncateMiddle(video.url, 40))}</span>
                                    </div>
                                </div>
                            </div>
                            <div class="action-group">
                                <button class="icon-btn" onclick="playVideo(${index})" title="Play">
                                    <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                                </button>
                                <button class="icon-btn" onclick="addToQueue(${index})" title="Add to Queue">
                                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                        <path d="M12 5v14M5 12h14"/>
                                    </svg>
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
                    
                    // 4. Render Pagination
                    const pagination = document.getElementById('pagination');
                    if (totalPages <= 1) {
                        pagination.style.display = 'none';
                    } else {
                        pagination.style.display = 'flex';
                        let html = '';
                        
                        // Prev
                        html += `<button class="page-btn" onclick="setPage(${currentPage - 1})" ${currentPage === 1 ? 'disabled' : ''}>&lt;</button>`;
                        
                        // Pages
                        let startPage = Math.max(1, currentPage - 2);
                        let endPage = Math.min(totalPages, startPage + 4);
                        if (endPage - startPage < 4) {
                            startPage = Math.max(1, endPage - 4);
                        }
                        
                        if (startPage > 1) {
                            html += `<button class="page-btn" onclick="setPage(1)">1</button>`;
                            if (startPage > 2) html += `<span>...</span>`;
                        }
                        
                        for (let i = startPage; i <= endPage; i++) {
                            html += `<button class="page-btn ${i === currentPage ? 'active' : ''}" onclick="setPage(${i})">${i}</button>`;
                        }
                        
                        if (endPage < totalPages) {
                            if (endPage < totalPages - 1) html += `<span>...</span>`;
                            html += `<button class="page-btn" onclick="setPage(${totalPages})">${totalPages}</button>`;
                        }
                        
                        // Next
                        html += `<button class="page-btn" onclick="setPage(${currentPage + 1})" ${currentPage === totalPages ? 'disabled' : ''}>&gt;</button>`;
                        
                        pagination.innerHTML = html;
                    }
                }
                
                function handleDragStart(e) {
                    e.dataTransfer.setData('text/plain', e.target.dataset.index);
                    e.target.style.opacity = '0.4';
                }
                
                function handleDragOver(e) {
                    e.preventDefault();
                    e.dataTransfer.dropEffect = 'move';
                }
                
                function handleDrop(e) {
                    e.preventDefault();
                    const draggedIndex = parseInt(e.dataTransfer.getData('text/plain'));
                    const targetRow = e.target.closest('.video-item');
                    if (!targetRow) return;
                    
                    targetRow.style.opacity = '1';
                    const targetIndex = parseInt(targetRow.dataset.index);
                    
                    if (draggedIndex === targetIndex) return;
                    
                    // Calculate new sort order
                    // We want to place dragged item BEFORE target item
                    // So we need a sortOrder > target's sortOrder
                    
                    const draggedVideo = currentVideos[draggedIndex];
                    const targetVideo = currentVideos[targetIndex];
                    
                    let newOrder = (targetVideo.sortOrder || 0) + 1;
                    
                    // If we are moving down (dragged index < target index in sorted list), 
                    // we might need to adjust logic depending on sort direction.
                    // Current sort: Descending (Larger is higher).
                    // If I drop A onto B, I want A to be above B? Or below?
                    // Standard drag drop: Drop ONTO usually means insert before.
                    // So A should have sortOrder > B.sortOrder.
                    // But if there is an item C above B with sortOrder = B.sortOrder + 1, we have a collision.
                    // Simple strategy: Just swap orders? No, that's messy.
                    // Better strategy: Assign newOrder = targetOrder + 1.
                    // But we need to shift others?
                    // For simplicity in this MVP: Just prompt or auto-increment.
                    // Let's try: newOrder = targetOrder + 1.
                    
                    // Actually, to support "insert between", we need to re-index or use floating point orders.
                    // Since we use Int, let's just swap for now or set to target + 1 and let the user fix collisions?
                    // Or better: Ask backend to "move A before B".
                    
                    // Let's implement a simple "Swap" for now, or just set the value.
                    // The user requirement: "Larger number = higher rank".
                    // If I drag A (order 0) to B (order 100), I probably want A to be 101.
                    
                    const newSortOrder = (targetVideo.sortOrder || 0) + 1;
                    handleSortOrderChange(draggedIndex, newSortOrder);
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
                            loadMedia();
                        } else {
                            alert('Error: ' + (res.error || 'Unknown'));
                        }
                    });
                }
                
                function openBatchMoveModal() {
                    populateGroupSelect('batchGroupInput');
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
                            loadMedia();
                        } else {
                            alert('Error: ' + (res.error || 'Unknown'));
                        }
                    });
                }
                
                function addToQueue(index) {
                    const video = currentVideos[index];
                    if (!video) return;
                    
                    fetch('/api/v1/queue', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({
                            videoId: video.id
                        })
                    })
                    .then(res => res.json())
                    .then(res => {
                        if (!res.success) {
                            alert('Failed to add to queue: ' + (res.message || 'Unknown error'));
                        }
                    });
                }
                
                function playVideo(index) {
                    fetch('/api/v1/control/play_video?index=' + index, { method: 'POST' });
                }
                
                function deleteVideo(index) {
                    if(confirm('Delete this stream?')) {
                        fetch('/api/v1/videos?index=' + index, { method: 'DELETE' })
                            .then(() => loadMedia());
                    }
                }
                
                function openEdit(index) {
                    const video = currentVideos[index];
                    document.getElementById('editIndex').value = index;
                    document.getElementById('editTitle').value = video.title;
                    document.getElementById('editUrl').value = video.url;
                    document.getElementById('editType').value = video.isLive ? 'live' : 'local';
                    
                    populateGroupSelect('editGroup', video.group);
                    
                    document.getElementById('editModal').classList.add('active');
                }
                
                function populateGroupSelect(elementId, selectedGroup) {
                    const select = document.getElementById(elementId);
                    select.innerHTML = '<option value="">Default</option>';
                    
                    const groups = new Set();
                    currentVideos.forEach(v => {
                        if (v.group) groups.add(v.group);
                    });
                    
                    Array.from(groups).sort().forEach(group => {
                        const option = document.createElement('option');
                        option.value = group;
                        option.textContent = group;
                        if (group === selectedGroup) {
                            option.selected = true;
                        }
                        select.appendChild(option);
                    });
                }
                
                function closeModal() {
                    document.getElementById('editModal').classList.remove('active');
                }
                
                function saveEdit() {
                    const index = document.getElementById('editIndex').value;
                    const data = {
                        title: document.getElementById('editTitle').value,
                        group: document.getElementById('editGroup').value,
                        url: document.getElementById('editUrl').value,
                        isLive: document.getElementById('editType').value === 'live'
                    };
                    
                    fetch('/api/v1/videos?index=' + index, {
                        method: 'PUT',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify(data)
                    }).then(() => {
                        closeModal();
                        loadMedia();
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
                
                let lastLoopTime = 0;

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
                            
                            // Update Queue from Status
                            if (data.queue) {
                                currentQueue = data.queue;
                                document.getElementById('mediaCount').textContent = currentQueue.length + ' items';
                                renderSidebar();
                            }
                            
                            // Update Current Playing ID
                            if (data.id !== currentPlayingId) {
                                currentPlayingId = data.id || null;
                            }

                            // Highlight Sidebar Item
                            document.querySelectorAll('.sidebar-item').forEach(el => {
                                el.style.background = 'transparent';
                                if(data.id && el.dataset.id === data.id) {
                                    el.style.background = '#f2f2f7';
                                }
                            });
                            
                            // Loop Logic
                            // Disabled client-side loop logic as it is now handled by the server queue
                            /*
                            if (loopEnabled && data.duration > 0 && data.id) {
                                const now = Date.now();
                                if (now - lastLoopTime < 5000) return; // Debounce 5s

                                // Check if near end (within 1s) or ended
                                if (data.currentTime >= data.duration - 1 && !data.isPlaying) {
                                    const currentIndex = currentVideos.findIndex(v => v.id === data.id);
                                    if (currentIndex !== -1) {
                                        let nextIndex = currentIndex + 1;
                                        if (nextIndex >= currentVideos.length) nextIndex = 0;
                                        
                                        console.log('Looping to next video:', nextIndex);
                                        playVideo(nextIndex);
                                        lastLoopTime = now;
                                    }
                                }
                            }
                            */
                        })
                        .catch(console.error);
                }
                
                setInterval(updateStatus, 1000);
                updateStatus();
                loadMedia();
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
                <span class="method">GET</span> <span class="url">/api/v1/media</span>
                <p>Get all videos in the media library.</p>
            </div>
            
            <div class="endpoint">
                <span class="method">POST</span> <span class="url">/api/v1/videos</span>
                <p>Add a new video.</p>
                <pre>
        {
          "title": "Channel Name",
          "url": "http://...",
          "group": "News",
          "isLive": true
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
                <span class="method">POST</span> <span class="url">/api/v1/media</span>
                <p>Replace the entire media library.</p>
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
