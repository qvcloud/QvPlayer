import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    private let dbName = "QvPlayer.sqlite"
    
    private init() {
        openDatabase()
        createTable()
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
            sort_order INTEGER DEFAULT 0
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
            ("sort_order", "INTEGER DEFAULT 0")
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
        ensureDatabaseIsOpen()
        guard let db = db else {
            DebugLogger.shared.error("Database is not open")
            return
        }
        let insertSQL = """
        INSERT INTO library (id, title, url, group_name, is_live, description, thumbnail_url, cached_url, latency, last_check, sort_order)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                DebugLogger.shared.error("Could not insert video.")
            }
        } else {
            DebugLogger.shared.error("INSERT video statement could not be prepared.")
        }
        sqlite3_finalize(stmt)
    }
    
    func updateVideo(_ video: Video) {
        ensureDatabaseIsOpen()
        guard let db = db else { return }
        let updateSQL = """
        UPDATE library SET 
            title = ?, url = ?, group_name = ?, is_live = ?, description = ?, 
            thumbnail_url = ?, cached_url = ?, latency = ?, last_check = ?, sort_order = ?
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
            sqlite3_bind_text(stmt, 11, (video.id.uuidString as NSString).utf8String, -1, nil)
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                DebugLogger.shared.error("Could not update video.")
            }
        } else {
            DebugLogger.shared.error("UPDATE video statement could not be prepared.")
        }
        sqlite3_finalize(stmt)
    }
    
    func deleteVideo(id: UUID) {
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
    
    func deleteAllVideos() {
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
    
    func getAllVideos() -> [Video] {
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
                        sortOrder: sortOrder
                    )
                    videos.append(video)
                }
            }
        }
        sqlite3_finalize(stmt)
        return videos
    }
    
    // Legacy support for migration
    func saveLatency(for url: String, latency: Double, lastCheck: Date) {
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
}
