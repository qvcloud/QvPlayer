import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    private let dbName = "QvPlayer.sqlite"
    private let queue = DispatchQueue(label: "com.qvplayer.database", qos: .userInitiated)
    
    private init() {
        queue.sync {
            openDatabase()
            createTable()
        }
    }
    
    private var primaryDbPath: String {
        //TODO: 这里为什么会失败在真机上？？？
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return ""
        }
        return appSupport.appendingPathComponent(dbName).path
    }
    
    private var fallbackDbPath: String {

        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return ""
        }
        return caches.appendingPathComponent(dbName).path
    }
    
    private func openDatabase() {
        // Try primary path (Application Support)
        if tryOpenDatabase(at: primaryDbPath) {
            return
        }
        
        DebugLogger.shared.warning("📝 [SQL] Failed to open primary database. Trying fallback to Caches...")
        
        // Try fallback path (Caches)
        if tryOpenDatabase(at: fallbackDbPath) {
            DebugLogger.shared.warning("📝 [SQL] Using fallback database in Caches directory.")
            return
        }
        
        DebugLogger.shared.error("📝 [SQL] Fatal: Could not open database in any location.")
        self.db = nil
    }
    
    private func tryOpenDatabase(at path: String) -> Bool {
        if path.isEmpty { return false }
        
        // Ensure directory exists
        let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            DebugLogger.shared.error("📝 [SQL] Failed to create directory at \(path): \(error.localizedDescription)")
        }
        
        DebugLogger.shared.info("📝 [SQL] Attempting to open database at: \(path)")
        
        var dbPtr: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &dbPtr, flags, nil) == SQLITE_OK {
            self.db = dbPtr
            DebugLogger.shared.info("📝 [SQL] Database opened successfully at \(path)")
            return true
        } else {
            if let dbPtr = dbPtr {
                let errorMsg = String(cString: sqlite3_errmsg(dbPtr))
                DebugLogger.shared.error("SQLite Error at \(path): \(errorMsg)")
                sqlite3_close(dbPtr)
            }
            return false
        }
    }
    
    private func ensureDatabaseIsOpen() {
        if db != nil { return }
        openDatabase()
        if db != nil {
            createTable()
        }
    }
    
    private func createTable() {
        guard let db = db else { return }
        
        // Old metadata table (can be dropped or ignored, but let's keep it for now or drop it?)
        // Let's create the new full library table
        let createTableString = """
        CREATE TABLE IF NOT EXISTS library(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            url TEXT NOT NULL,
            group_name TEXT,
            is_live INTEGER DEFAULT 0,
            description TEXT,
            thumbnail_url TEXT,
            cached_url TEXT,
            latency REAL,
            last_check REAL,
            sort_order INTEGER DEFAULT 0,
            file_size INTEGER,
            creation_date REAL,
            tvg_name TEXT
        );
        """
        DebugLogger.shared.info("📝 [SQL] Executing: \(createTableString)")
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                // Table created
            } else {
                DebugLogger.shared.error("Table library could not be created.")
            }
        } else {
            DebugLogger.shared.error("CREATE TABLE library statement could not be prepared.")
        }
        sqlite3_finalize(createTableStatement)
        
        // Create Play Queue Table
        // Drop old table to enforce new schema
        sqlite3_exec(db, "DROP TABLE IF EXISTS play_queue;", nil, nil, nil)
        
        let createQueueTableString = """
        CREATE TABLE IF NOT EXISTS play_queue(
            id TEXT PRIMARY KEY,
            video_id TEXT NOT NULL,
            sort_order INTEGER DEFAULT 0,
            status TEXT DEFAULT 'pending',
            loop INTEGER DEFAULT 0
        );
        """
        DebugLogger.shared.info("📝 [SQL] Executing: \(createQueueTableString)")
        var createQueueStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, createQueueTableString, -1, &createQueueStmt, nil) == SQLITE_OK {
            if sqlite3_step(createQueueStmt) == SQLITE_DONE {
                // Table created
            } else {
                DebugLogger.shared.error("Table play_queue could not be created.")
            }
        } else {
            DebugLogger.shared.error("CREATE TABLE play_queue statement could not be prepared.")
        }
        sqlite3_finalize(createQueueStmt)
        
        // Create Batches Table
        let createBatchesTableString = """
        CREATE TABLE IF NOT EXISTS batches(
            id TEXT PRIMARY KEY,
            name TEXT,
            is_looping INTEGER DEFAULT 0,
            created_at REAL
        );
        """
        DebugLogger.shared.info("📝 [SQL] Executing: \(createBatchesTableString)")
        var createBatchesStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, createBatchesTableString, -1, &createBatchesStmt, nil) == SQLITE_OK {
            if sqlite3_step(createBatchesStmt) == SQLITE_DONE {
                // Table created
            } else {
                DebugLogger.shared.error("Table batches could not be created.")
            }
        } else {
            DebugLogger.shared.error("CREATE TABLE batches statement could not be prepared.")
        }
        sqlite3_finalize(createBatchesStmt)
        
        // Create Config Table
        let createConfigTableString = """
        CREATE TABLE IF NOT EXISTS app_config(
            key TEXT PRIMARY KEY,
            value TEXT
        );
        """
        DebugLogger.shared.info("📝 [SQL] Executing: \(createConfigTableString)")
        var createConfigStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, createConfigTableString, -1, &createConfigStmt, nil) == SQLITE_OK {
            if sqlite3_step(createConfigStmt) == SQLITE_DONE {
                // Table created
            } else {
                DebugLogger.shared.error("Table app_config could not be created.")
            }
        } else {
            DebugLogger.shared.error("CREATE TABLE app_config statement could not be prepared.")
        }
        sqlite3_finalize(createConfigStmt)
        
        migrateSchema()
        
        // Migration: Rename videos to library if it exists and library is empty
        // Or just check if videos exists and rename it?
        // Simple check: try to select from videos. If success, and library is empty, move data?
        // Actually, simpler: ALTER TABLE videos RENAME TO library;
        // But we just created library if not exists.
        // If 'videos' exists, we should probably migrate data from it to 'library' then drop 'videos'.
        
        let checkVideosTable = "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='videos';"
        var checkStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, checkVideosTable, -1, &checkStmt, nil) == SQLITE_OK {
            if sqlite3_step(checkStmt) == SQLITE_ROW {
                let count = sqlite3_column_int(checkStmt, 0)
                if count > 0 {
                    DebugLogger.shared.info("📝 [SQL] Found legacy 'videos' table. Migrating to 'library'...")
                    let migrateSQL = "INSERT INTO library SELECT * FROM videos;"
                    var migrateStmt: OpaquePointer?
                    if sqlite3_prepare_v2(db, migrateSQL, -1, &migrateStmt, nil) == SQLITE_OK {
                        if sqlite3_step(migrateStmt) == SQLITE_DONE {
                            DebugLogger.shared.info("📝 [SQL] Migration successful. Dropping 'videos' table.")
                            let dropSQL = "DROP TABLE videos;"
                            var dropStmt: OpaquePointer?
                            if sqlite3_prepare_v2(db, dropSQL, -1, &dropStmt, nil) == SQLITE_OK {
                                sqlite3_step(dropStmt)
                            }
                            sqlite3_finalize(dropStmt)
                        }
                    }
                    sqlite3_finalize(migrateStmt)
                }
            }
        }
        sqlite3_finalize(checkStmt)
    }
    
    private func migrateSchema() {
        guard let db = db else { return }
        
        let columns = [
            ("group_name", "TEXT"),
            ("is_live", "INTEGER DEFAULT 0"),
            ("description", "TEXT"),
            ("thumbnail_url", "TEXT"),
            ("cached_url", "TEXT"),
            ("latency", "REAL"),
            ("last_check", "REAL"),
            ("sort_order", "INTEGER DEFAULT 0"),
            ("file_size", "INTEGER"),
            ("creation_date", "REAL"),
            ("tvg_name", "TEXT")
        ]
        
        for (name, type) in columns {
            let sql = "ALTER TABLE library ADD COLUMN \(name) \(type);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_DONE {
                    DebugLogger.shared.info("📝 [SQL] Added column \(name) to library table")
                }
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func addVideo(_ video: Video) {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else {
                DebugLogger.shared.error("Database is not open")
                return
            }
            let insertSQL = """
            INSERT INTO library (id, title, url, group_name, is_live, description, thumbnail_url, cached_url, latency, last_check, sort_order, file_size, creation_date, tvg_name)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            DebugLogger.shared.info("📝 [SQL] Executing: INSERT INTO library... \(video.title)")
            
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (video.id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (video.title as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (video.url.absoluteString as NSString).utf8String, -1, nil)
                
                if let group = video.group {
                    sqlite3_bind_text(stmt, 4, (group as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 4)
                }
                
                sqlite3_bind_int(stmt, 5, video.isLive ? 1 : 0)
                
                if let desc = video.description {
                    sqlite3_bind_text(stmt, 6, (desc as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }
                
                if let thumb = video.thumbnailURL {
                    sqlite3_bind_text(stmt, 7, (thumb.absoluteString as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                
                if let cached = video.cachedURL {
                    sqlite3_bind_text(stmt, 8, (cached.absoluteString as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 8)
                }
                
                if let latency = video.latency {
                    sqlite3_bind_double(stmt, 9, latency)
                } else {
                    sqlite3_bind_null(stmt, 9)
                }
                
                if let lastCheck = video.lastLatencyCheck {
                    sqlite3_bind_double(stmt, 10, lastCheck.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(stmt, 10)
                }
                
                sqlite3_bind_int(stmt, 11, Int32(video.sortOrder))
                
                if let size = video.fileSize {
                    sqlite3_bind_int64(stmt, 12, size)
                } else {
                    sqlite3_bind_null(stmt, 12)
                }
                
                if let date = video.creationDate {
                    sqlite3_bind_double(stmt, 13, date.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(stmt, 13)
                }

                if let tvgName = video.tvgName {
                    sqlite3_bind_text(stmt, 14, (tvgName as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 14)
                }
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    DebugLogger.shared.error("Could not insert video.")
                }
            } else {
                DebugLogger.shared.error("INSERT video statement could not be prepared.")
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func addVideos(_ videos: [Video]) {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            
            sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
            
            let insertSQL = """
            INSERT INTO library (id, title, url, group_name, is_live, description, thumbnail_url, cached_url, latency, last_check, sort_order, file_size, creation_date, tvg_name)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
                for video in videos {
                    sqlite3_bind_text(stmt, 1, (video.id.uuidString as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 2, (video.title as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 3, (video.url.absoluteString as NSString).utf8String, -1, nil)
                    
                    if let group = video.group {
                        sqlite3_bind_text(stmt, 4, (group as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(stmt, 4)
                    }
                    
                    sqlite3_bind_int(stmt, 5, video.isLive ? 1 : 0)
                    
                    if let desc = video.description {
                        sqlite3_bind_text(stmt, 6, (desc as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(stmt, 6)
                    }
                    
                    if let thumb = video.thumbnailURL {
                        sqlite3_bind_text(stmt, 7, (thumb.absoluteString as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(stmt, 7)
                    }
                    
                    if let cached = video.cachedURL {
                        sqlite3_bind_text(stmt, 8, (cached.absoluteString as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(stmt, 8)
                    }
                    
                    if let latency = video.latency {
                        sqlite3_bind_double(stmt, 9, latency)
                    } else {
                        sqlite3_bind_null(stmt, 9)
                    }
                    
                    if let lastCheck = video.lastLatencyCheck {
                        sqlite3_bind_double(stmt, 10, lastCheck.timeIntervalSince1970)
                    } else {
                        sqlite3_bind_null(stmt, 10)
                    }
                    
                    sqlite3_bind_int(stmt, 11, Int32(video.sortOrder))
                    
                    if let size = video.fileSize {
                        sqlite3_bind_int64(stmt, 12, size)
                    } else {
                        sqlite3_bind_null(stmt, 12)
                    }
                    
                    if let date = video.creationDate {
                        sqlite3_bind_double(stmt, 13, date.timeIntervalSince1970)
                    } else {
                        sqlite3_bind_null(stmt, 13)
                    }

                    if let tvgName = video.tvgName {
                        sqlite3_bind_text(stmt, 14, (tvgName as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(stmt, 14)
                    }
                    
                    if sqlite3_step(stmt) != SQLITE_DONE {
                        DebugLogger.shared.error("Could not insert video in batch.")
                    }
                    sqlite3_reset(stmt)
                }
            } else {
                DebugLogger.shared.error("Batch INSERT statement could not be prepared.")
            }
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "COMMIT", nil, nil, nil)
        }
    }
    
    func updateVideo(_ video: Video) {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            let updateSQL = """
            UPDATE library SET 
                title = ?, url = ?, group_name = ?, is_live = ?, description = ?, 
                thumbnail_url = ?, cached_url = ?, latency = ?, last_check = ?, sort_order = ?,
                file_size = ?, creation_date = ?, tvg_name = ?
            WHERE id = ?;
            """
            DebugLogger.shared.info("📝 [SQL] Executing: UPDATE library... \(video.title)")
            
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, updateSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (video.title as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (video.url.absoluteString as NSString).utf8String, -1, nil)
                
                if let group = video.group {
                    sqlite3_bind_text(stmt, 3, (group as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 3)
                }
                
                sqlite3_bind_int(stmt, 4, video.isLive ? 1 : 0)
                
                if let desc = video.description {
                    sqlite3_bind_text(stmt, 5, (desc as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 5)
                }
                
                if let thumb = video.thumbnailURL {
                    sqlite3_bind_text(stmt, 6, (thumb.absoluteString as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }
                
                if let cached = video.cachedURL {
                    sqlite3_bind_text(stmt, 7, (cached.absoluteString as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                
                if let latency = video.latency {
                    sqlite3_bind_double(stmt, 8, latency)
                } else {
                    sqlite3_bind_null(stmt, 8)
                }
                
                if let lastCheck = video.lastLatencyCheck {
                    sqlite3_bind_double(stmt, 9, lastCheck.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(stmt, 9)
                }
                
                sqlite3_bind_int(stmt, 10, Int32(video.sortOrder))
                
                if let size = video.fileSize {
                    sqlite3_bind_int64(stmt, 11, size)
                } else {
                    sqlite3_bind_null(stmt, 11)
                }
                
                if let date = video.creationDate {
                    sqlite3_bind_double(stmt, 12, date.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(stmt, 12)
                }

                if let tvgName = video.tvgName {
                    sqlite3_bind_text(stmt, 13, (tvgName as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 13)
                }
                
                sqlite3_bind_text(stmt, 14, (video.id.uuidString as NSString).utf8String, -1, nil)
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    DebugLogger.shared.error("Could not update video.")
                }
            } else {
                DebugLogger.shared.error("UPDATE video statement could not be prepared.")
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func deleteVideo(id: UUID) {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            let deleteSQL = "DELETE FROM library WHERE id = ?;"
            DebugLogger.shared.info("📝 [SQL] Executing: DELETE FROM library WHERE id = \(id)")
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id.uuidString as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) != SQLITE_DONE {
                    DebugLogger.shared.error("Could not delete video.")
                }
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func deleteAllVideos() {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            let deleteSQL = "DELETE FROM library;"
            DebugLogger.shared.info("📝 [SQL] Executing: DELETE FROM library")
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) != SQLITE_DONE {
                    DebugLogger.shared.error("Could not delete all videos.")
                }
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func getAllVideos() -> [Video] {
        return queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return [] }
            var videos = [Video]()
            let querySQL = "SELECT * FROM library ORDER BY sort_order DESC;"
            DebugLogger.shared.info("📝 [SQL] Executing: \(querySQL)")
            
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let idStr = String(cString: sqlite3_column_text(stmt, 0))
                    let title = String(cString: sqlite3_column_text(stmt, 1))
                    let urlStr = String(cString: sqlite3_column_text(stmt, 2))
                    
                    var group: String?
                    if let ptr = sqlite3_column_text(stmt, 3) {
                        group = String(cString: ptr)
                    }
                    
                    let isLive = sqlite3_column_int(stmt, 4) != 0
                    
                    var description: String?
                    if let ptr = sqlite3_column_text(stmt, 5) {
                        description = String(cString: ptr)
                    }
                    
                    var thumbnailURL: URL?
                    if let ptr = sqlite3_column_text(stmt, 6) {
                        thumbnailURL = URL(string: String(cString: ptr))
                    }
                    
                    var cachedURL: URL?
                    if let ptr = sqlite3_column_text(stmt, 7) {
                        cachedURL = URL(string: String(cString: ptr))
                    }
                    
                    var latency: Double?
                    if sqlite3_column_type(stmt, 8) != SQLITE_NULL {
                        latency = sqlite3_column_double(stmt, 8)
                    }
                    
                    var lastCheck: Date?
                    if sqlite3_column_type(stmt, 9) != SQLITE_NULL {
                        lastCheck = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 9))
                    }
                    
                    let sortOrder = Int(sqlite3_column_int(stmt, 10))
                    
                    var fileSize: Int64?
                    if sqlite3_column_type(stmt, 11) != SQLITE_NULL {
                        fileSize = sqlite3_column_int64(stmt, 11)
                    }
                    
                    var creationDate: Date?
                    if sqlite3_column_type(stmt, 12) != SQLITE_NULL {
                        creationDate = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 12))
                    }

                    var tvgName: String?
                    if let ptr = sqlite3_column_text(stmt, 13) {
                        tvgName = String(cString: ptr)
                    }
                    
                    if let id = UUID(uuidString: idStr), let url = URL(string: urlStr) {
                        let video = Video(
                            id: id,
                            title: title,
                            url: url,
                            group: group,
                            isLive: isLive,
                            description: description,
                            thumbnailURL: thumbnailURL,
                            cachedURL: cachedURL,
                            latency: latency,
                            lastLatencyCheck: lastCheck,
                            sortOrder: sortOrder,
                            fileSize: fileSize,
                            creationDate: creationDate,
                            tvgName: tvgName
                        )
                        videos.append(video)
                    }
                }
            }
            sqlite3_finalize(stmt)
            return videos
        }
    }
    
    func getVideos(byTvgName name: String) -> [Video] {
        return queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return [] }
            var videos = [Video]()
            let querySQL = "SELECT * FROM library WHERE tvg_name = ? ORDER BY sort_order DESC;"
            
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let idStr = String(cString: sqlite3_column_text(stmt, 0))
                    let title = String(cString: sqlite3_column_text(stmt, 1))
                    let urlStr = String(cString: sqlite3_column_text(stmt, 2))
                    
                    var group: String?
                    if let ptr = sqlite3_column_text(stmt, 3) {
                        group = String(cString: ptr)
                    }
                    
                    let isLive = sqlite3_column_int(stmt, 4) != 0
                    
                    var description: String?
                    if let ptr = sqlite3_column_text(stmt, 5) {
                        description = String(cString: ptr)
                    }
                    
                    var thumbnailURL: URL?
                    if let ptr = sqlite3_column_text(stmt, 6) {
                        thumbnailURL = URL(string: String(cString: ptr))
                    }
                    
                    var cachedURL: URL?
                    if let ptr = sqlite3_column_text(stmt, 7) {
                        cachedURL = URL(string: String(cString: ptr))
                    }
                    
                    var latency: Double?
                    if sqlite3_column_type(stmt, 8) != SQLITE_NULL {
                        latency = sqlite3_column_double(stmt, 8)
                    }
                    
                    var lastCheck: Date?
                    if sqlite3_column_type(stmt, 9) != SQLITE_NULL {
                        lastCheck = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 9))
                    }
                    
                    let sortOrder = Int(sqlite3_column_int(stmt, 10))
                    
                    var fileSize: Int64?
                    if sqlite3_column_type(stmt, 11) != SQLITE_NULL {
                        fileSize = sqlite3_column_int64(stmt, 11)
                    }
                    
                    var creationDate: Date?
                    if sqlite3_column_type(stmt, 12) != SQLITE_NULL {
                        creationDate = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 12))
                    }

                    var tvgName: String?
                    if let ptr = sqlite3_column_text(stmt, 13) {
                        tvgName = String(cString: ptr)
                    }
                    
                    if let id = UUID(uuidString: idStr), let url = URL(string: urlStr) {
                        let video = Video(
                            id: id,
                            title: title,
                            url: url,
                            group: group,
                            isLive: isLive,
                            description: description,
                            thumbnailURL: thumbnailURL,
                            cachedURL: cachedURL,
                            latency: latency,
                            lastLatencyCheck: lastCheck,
                            sortOrder: sortOrder,
                            fileSize: fileSize,
                            creationDate: creationDate,
                            tvgName: tvgName
                        )
                        videos.append(video)
                    }
                }
            }
            sqlite3_finalize(stmt)
            return videos
        }
    }
    
    // Legacy support for migration
    func saveLatency(for url: String, latency: Double, lastCheck: Date) {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            // Also update the main library table if it exists
            let updateSQL = "UPDATE library SET latency = ?, last_check = ? WHERE url = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, updateSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_double(stmt, 1, latency)
                sqlite3_bind_double(stmt, 2, lastCheck.timeIntervalSince1970)
                sqlite3_bind_text(stmt, 3, (url as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func getVideosForSpeedTest(limit: Int = 10) -> [Video] {
        return queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return [] }
            var videos = [Video]()
            // Prioritize videos with NULL latency, then oldest check
            let querySQL = "SELECT * FROM library WHERE latency IS NULL OR last_check IS NULL ORDER BY RANDOM() LIMIT ?;"
            
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(limit))
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let idStr = String(cString: sqlite3_column_text(stmt, 0))
                    let title = String(cString: sqlite3_column_text(stmt, 1))
                    let urlStr = String(cString: sqlite3_column_text(stmt, 2))
                    
                    var group: String?
                    if let ptr = sqlite3_column_text(stmt, 3) {
                        group = String(cString: ptr)
                    }
                    
                    let isLive = sqlite3_column_int(stmt, 4) != 0
                    
                    var description: String?
                    if let ptr = sqlite3_column_text(stmt, 5) {
                        description = String(cString: ptr)
                    }
                    
                    var thumbnailURL: URL?
                    if let ptr = sqlite3_column_text(stmt, 6) {
                        thumbnailURL = URL(string: String(cString: ptr))
                    }
                    
                    var cachedURL: URL?
                    if let ptr = sqlite3_column_text(stmt, 7) {
                        cachedURL = URL(string: String(cString: ptr))
                    }
                    
                    var latency: Double?
                    if sqlite3_column_type(stmt, 8) != SQLITE_NULL {
                        latency = sqlite3_column_double(stmt, 8)
                    }
                    
                    var lastCheck: Date?
                    if sqlite3_column_type(stmt, 9) != SQLITE_NULL {
                        lastCheck = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 9))
                    }
                    
                    let sortOrder = Int(sqlite3_column_int(stmt, 10))
                    
                    var fileSize: Int64?
                    if sqlite3_column_type(stmt, 11) != SQLITE_NULL {
                        fileSize = sqlite3_column_int64(stmt, 11)
                    }
                    
                    var creationDate: Date?
                    if sqlite3_column_type(stmt, 12) != SQLITE_NULL {
                        creationDate = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 12))
                    }

                    var tvgName: String?
                    if let ptr = sqlite3_column_text(stmt, 13) {
                        tvgName = String(cString: ptr)
                    }
                    
                    if let id = UUID(uuidString: idStr), let url = URL(string: urlStr) {
                        let video = Video(
                            id: id,
                            title: title,
                            url: url,
                            group: group,
                            isLive: isLive,
                            description: description,
                            thumbnailURL: thumbnailURL,
                            cachedURL: cachedURL,
                            latency: latency,
                            lastLatencyCheck: lastCheck,
                            sortOrder: sortOrder,
                            fileSize: fileSize,
                            creationDate: creationDate,
                            tvgName: tvgName
                        )
                        videos.append(video)
                    }
                }
            }
            sqlite3_finalize(stmt)
            return videos
        }
    }
    
    func getAdjacentChannel(currentTvgName: String, offset: Int) -> Video? {
        return queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return nil }
            
            // 1. Get all distinct tvg_names for live streams, sorted
            // Note: We use a simple query here. For very large datasets, this should be optimized or cached.
            let querySQL = "SELECT DISTINCT tvg_name FROM library WHERE is_live = 1 AND tvg_name IS NOT NULL ORDER BY tvg_name ASC;"
            
            var tvgNames = [String]()
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let ptr = sqlite3_column_text(stmt, 0) {
                        tvgNames.append(String(cString: ptr))
                    }
                }
            }
            sqlite3_finalize(stmt)
            
            guard !tvgNames.isEmpty else { return nil }
            
            // 2. Find current index
            guard let currentIndex = tvgNames.firstIndex(of: currentTvgName) else {
                // If current not found, maybe return first?
                return nil
            }
            
            // 3. Calculate target index with wrapping
            var targetIndex = currentIndex + offset
            if targetIndex < 0 { targetIndex = tvgNames.count - 1 }
            if targetIndex >= tvgNames.count { targetIndex = 0 }
            
            let targetTvgName = tvgNames[targetIndex]
            
            // 4. Get best video for target tvg_name
            // Exclude latency = -1 (failed)
            // Prioritize lowest positive latency, then NULL (untested)
            let videoQuery = "SELECT * FROM library WHERE tvg_name = ? AND (latency IS NULL OR latency != -1) ORDER BY CASE WHEN latency IS NULL THEN 1 ELSE 0 END, latency ASC LIMIT 1;"
            var videoStmt: OpaquePointer?
            var resultVideo: Video?
            
            if sqlite3_prepare_v2(db, videoQuery, -1, &videoStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(videoStmt, 1, (targetTvgName as NSString).utf8String, -1, nil)
                
                if sqlite3_step(videoStmt) == SQLITE_ROW {
                    // Parse Video (Simplified for brevity, assuming we need basic fields to play)
                    // We need full object to be safe.
                    let idStr = String(cString: sqlite3_column_text(videoStmt, 0))
                    let title = String(cString: sqlite3_column_text(videoStmt, 1))
                    let urlStr = String(cString: sqlite3_column_text(videoStmt, 2))
                    
                    var group: String?
                    if let ptr = sqlite3_column_text(videoStmt, 3) { group = String(cString: ptr) }
                    let isLive = sqlite3_column_int(videoStmt, 4) != 0
                    var description: String?
                    if let ptr = sqlite3_column_text(videoStmt, 5) { description = String(cString: ptr) }
                    var thumbnailURL: URL?
                    if let ptr = sqlite3_column_text(videoStmt, 6) { thumbnailURL = URL(string: String(cString: ptr)) }
                    var cachedURL: URL?
                    if let ptr = sqlite3_column_text(videoStmt, 7) { cachedURL = URL(string: String(cString: ptr)) }
                    var latency: Double?
                    if sqlite3_column_type(videoStmt, 8) != SQLITE_NULL { latency = sqlite3_column_double(videoStmt, 8) }
                    var lastCheck: Date?
                    if sqlite3_column_type(videoStmt, 9) != SQLITE_NULL { lastCheck = Date(timeIntervalSince1970: sqlite3_column_double(videoStmt, 9)) }
                    let sortOrder = Int(sqlite3_column_int(videoStmt, 10))
                    var fileSize: Int64?
                    if sqlite3_column_type(videoStmt, 11) != SQLITE_NULL { fileSize = sqlite3_column_int64(videoStmt, 11) }
                    var creationDate: Date?
                    if sqlite3_column_type(videoStmt, 12) != SQLITE_NULL { creationDate = Date(timeIntervalSince1970: sqlite3_column_double(videoStmt, 12)) }
                    var tvgName: String?
                    if let ptr = sqlite3_column_text(videoStmt, 13) { tvgName = String(cString: ptr) }
                    
                    if let id = UUID(uuidString: idStr), let url = URL(string: urlStr) {
                        resultVideo = Video(
                            id: id, title: title, url: url, group: group, isLive: isLive,
                            description: description, thumbnailURL: thumbnailURL, cachedURL: cachedURL,
                            latency: latency, lastLatencyCheck: lastCheck, sortOrder: sortOrder,
                            fileSize: fileSize, creationDate: creationDate, tvgName: tvgName
                        )
                    }
                }
            }
            sqlite3_finalize(videoStmt)
            
            return resultVideo
        }
    }
    
    func getAllMetadata() -> [String: (Double, Date)] {
        ensureDatabaseIsOpen()
        guard let db = db else { return [:] }
        var result = [String: (Double, Date)]()
        let queryStatementString = "SELECT url, latency, last_check FROM video_metadata;"
        DebugLogger.shared.info("📝 [SQL] Executing: \(queryStatementString)")
        var queryStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                if let urlPtr = sqlite3_column_text(queryStatement, 0) {
                    let url = String(cString: urlPtr)
                    let latency = sqlite3_column_double(queryStatement, 1)
                    let lastCheckTimestamp = sqlite3_column_double(queryStatement, 2)
                    result[url] = (latency, Date(timeIntervalSince1970: lastCheckTimestamp))
                }
            }
        }
        sqlite3_finalize(queryStatement)
        return result
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - Play Queue Management
    
    func addPlayQueueItem(_ item: PlayQueueItem) {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            
            let insertSQL = "INSERT INTO play_queue (id, video_id, sort_order, status) VALUES (?, ?, ?, ?);"
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (item.id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (item.videoId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 3, Int32(item.sortOrder))
                sqlite3_bind_text(stmt, 4, (item.status.rawValue as NSString).utf8String, -1, nil)
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    DebugLogger.shared.error("Error inserting play queue item")
                }
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func getPlayQueue() -> [PlayQueueItem] {
        return queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return [] }
            
            let querySQL = """
            SELECT q.id, q.video_id, q.sort_order, q.status,
                   l.id, l.title, l.url, l.group_name, l.is_live, l.description, l.thumbnail_url, l.cached_url, l.latency, l.last_check, l.sort_order, l.file_size, l.creation_date
            FROM play_queue q
            LEFT JOIN library l ON q.video_id = l.id
            ORDER BY q.sort_order ASC;
            """
            
            var stmt: OpaquePointer?
            var items: [PlayQueueItem] = []
            
            if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    // Queue Item Fields
                    guard let qIdStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                          let qId = UUID(uuidString: qIdStr),
                          let vIdStr = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
                          let vId = UUID(uuidString: vIdStr) else {
                        continue
                    }
                    
                    let qSort = Int(sqlite3_column_int(stmt, 2))
                    let statusStr = sqlite3_column_text(stmt, 3).map({ String(cString: $0) }) ?? "pending"
                    let status = PlayQueueStatus(rawValue: statusStr) ?? .pending
                    
                    // Video Fields (Joined)
                    var video: Video? = nil
                    if let lIdStr = sqlite3_column_text(stmt, 4).map({ String(cString: $0) }),
                       let lId = UUID(uuidString: lIdStr),
                       let title = sqlite3_column_text(stmt, 5).map({ String(cString: $0) }),
                       let urlStr = sqlite3_column_text(stmt, 6).map({ String(cString: $0) }),
                       let url = URL(string: urlStr) {
                        
                        let group = sqlite3_column_text(stmt, 7).map({ String(cString: $0) })
                        let isLive = sqlite3_column_int(stmt, 8) != 0
                        let desc = sqlite3_column_text(stmt, 9).map({ String(cString: $0) })
                        let thumb = sqlite3_column_text(stmt, 10).map({ String(cString: $0) }).flatMap { URL(string: $0) }
                        let cached = sqlite3_column_text(stmt, 11).map({ String(cString: $0) }).flatMap { URL(string: $0) }
                        
                        var latency: Double?
                        if sqlite3_column_type(stmt, 12) != SQLITE_NULL {
                            latency = sqlite3_column_double(stmt, 12)
                        }
                        
                        var lastCheck: Date?
                        if sqlite3_column_type(stmt, 13) != SQLITE_NULL {
                            lastCheck = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 13))
                        }
                        
                        let lSort = Int(sqlite3_column_int(stmt, 14))
                        
                        var fileSize: Int64?
                        if sqlite3_column_type(stmt, 15) != SQLITE_NULL {
                            fileSize = sqlite3_column_int64(stmt, 15)
                        }
                        
                        var creationDate: Date?
                        if sqlite3_column_type(stmt, 16) != SQLITE_NULL {
                            creationDate = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 16))
                        }
                        
                        video = Video(id: lId, title: title, url: url, group: group, isLive: isLive, description: desc, thumbnailURL: thumb, cachedURL: cached, latency: latency, lastLatencyCheck: lastCheck, sortOrder: lSort, fileSize: fileSize, creationDate: creationDate)
                    }
                    
                    items.append(PlayQueueItem(id: qId, videoId: vId, sortOrder: qSort, status: status, video: video))
                }
            }
            sqlite3_finalize(stmt)
            return items
        }
    }
    
    func updatePlayQueueStatus(id: UUID, status: PlayQueueStatus) {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            
            let sql = "UPDATE play_queue SET status = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (status.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func updatePlayQueueSortOrder(id: UUID, sortOrder: Int) {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            
            let sql = "UPDATE play_queue SET sort_order = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(sortOrder))
                sqlite3_bind_text(stmt, 2, (id.uuidString as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func resetPlayQueueStatus() {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            
            let sql = "UPDATE play_queue SET status = 'pending';"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func clearPlayQueue() {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            
            let sql = "DELETE FROM play_queue;"
            
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    func removePlayQueueItem(id: UUID) {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            
            let sql = "DELETE FROM play_queue WHERE id = ?;"
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                let uuidString = id.uuidString as NSString
                sqlite3_bind_text(stmt, 1, uuidString.utf8String, -1, nil)
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    let errmsg = String(cString: sqlite3_errmsg(db))
                    DebugLogger.shared.error("Error removing play queue item: \(errmsg)")
                }
            }
            sqlite3_finalize(stmt)
        }
    }
    
    // MARK: - Batch Management
    
    func createBatch(id: String, name: String, isLooping: Bool) {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            
            let sql = "INSERT OR REPLACE INTO batches (id, name, is_looping, created_at) VALUES (?, ?, ?, ?);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (name as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 3, isLooping ? 1 : 0)
                sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func getBatch(id: String) -> (name: String, isLooping: Bool)? {
        return queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return nil }
            
            let sql = "SELECT name, is_looping FROM batches WHERE id = ?;"
            var stmt: OpaquePointer?
            var result: (String, Bool)?
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let name = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }) {
                        let isLooping = sqlite3_column_int(stmt, 1) != 0
                        result = (name, isLooping)
                    }
                }
            }
            sqlite3_finalize(stmt)
            return result
        }
    }
    
    func deleteBatch(id: String) {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            
            let sql = "DELETE FROM batches WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    // MARK: - App Config
    
    func setConfig(key: String, value: String) {
        queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return }
            
            let sql = "INSERT OR REPLACE INTO app_config (key, value) VALUES (?, ?);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (value as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func getConfig(key: String) -> String? {
        return queue.sync {
            ensureDatabaseIsOpen()
            guard let db = db else { return nil }
            
            let sql = "SELECT value FROM app_config WHERE key = ?;"
            var stmt: OpaquePointer?
            var result: String?
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let val = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }) {
                        result = val
                    }
                }
            }
            sqlite3_finalize(stmt)
            return result
        }
    }
    
    // MARK: - User Agent Management
    
    struct UserAgentItem: Codable {
        let name: String
        let value: String
        let isSystem: Bool
    }
    
    private let systemUserAgents: [UserAgentItem] = [
        UserAgentItem(name: "Default", value: AppConstants.defaultUserAgent, isSystem: true),
        UserAgentItem(name: "Chrome (Windows)", value: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", isSystem: true),
        UserAgentItem(name: "Safari (macOS)", value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15", isSystem: true),
        UserAgentItem(name: "iPhone", value: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1", isSystem: true),
        UserAgentItem(name: "iPad", value: "Mozilla/5.0 (iPad; CPU OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1", isSystem: true),
        UserAgentItem(name: "Android Mobile", value: "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36", isSystem: true),
        UserAgentItem(name: "Smart TV (Generic)", value: "Mozilla/5.0 (Web0S; Linux/SmartTV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.79 Safari/537.36 WebAppManager", isSystem: true)
    ]
    
    func getAllUserAgents() -> [UserAgentItem] {
        var items = systemUserAgents
        
        if let customJson = getConfig(key: "custom_user_agents"),
           let data = customJson.data(using: .utf8),
           let customItems = try? JSONDecoder().decode([UserAgentItem].self, from: data) {
            items.append(contentsOf: customItems)
        }
        
        return items
    }
    
    func addCustomUserAgent(name: String, value: String) {
        var customItems: [UserAgentItem] = []
        if let customJson = getConfig(key: "custom_user_agents"),
           let data = customJson.data(using: .utf8),
           let existing = try? JSONDecoder().decode([UserAgentItem].self, from: data) {
            customItems = existing
        }
        
        // Remove existing with same name if any (update)
        customItems.removeAll { $0.name == name }
        
        let newItem = UserAgentItem(name: name, value: value, isSystem: false)
        customItems.append(newItem)
        
        if let data = try? JSONEncoder().encode(customItems),
           let jsonString = String(data: data, encoding: .utf8) {
            setConfig(key: "custom_user_agents", value: jsonString)
        }
    }
    
    func removeCustomUserAgent(name: String) {
        guard var customItems: [UserAgentItem] = {
            if let customJson = getConfig(key: "custom_user_agents"),
               let data = customJson.data(using: .utf8),
               let existing = try? JSONDecoder().decode([UserAgentItem].self, from: data) {
                return existing
            }
            return []
        }() else { return }
        
        customItems.removeAll { $0.name == name }
        
        if let data = try? JSONEncoder().encode(customItems),
           let jsonString = String(data: data, encoding: .utf8) {
            setConfig(key: "custom_user_agents", value: jsonString)
        }
    }
}

