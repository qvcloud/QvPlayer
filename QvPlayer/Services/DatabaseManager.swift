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
    
    private var dbPath: String {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(dbName).path
    }
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            DebugLogger.shared.error("Error opening database")
        }
    }
    
    private func createTable() {
        let createTableString = """
        CREATE TABLE IF NOT EXISTS video_metadata(
            url TEXT PRIMARY KEY,
            latency REAL,
            last_check REAL
        );
        """
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                // Table created
            } else {
                DebugLogger.shared.error("Table could not be created.")
            }
        } else {
            DebugLogger.shared.error("CREATE TABLE statement could not be prepared.")
        }
        sqlite3_finalize(createTableStatement)
    }
    
    func saveLatency(for url: String, latency: Double, lastCheck: Date) {
        let insertStatementString = "INSERT OR REPLACE INTO video_metadata (url, latency, last_check) VALUES (?, ?, ?);"
        var insertStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, (url as NSString).utf8String, -1, nil)
            sqlite3_bind_double(insertStatement, 2, latency)
            sqlite3_bind_double(insertStatement, 3, lastCheck.timeIntervalSince1970)
            
            if sqlite3_step(insertStatement) != SQLITE_DONE {
                DebugLogger.shared.error("Could not insert row.")
            }
        } else {
            DebugLogger.shared.error("INSERT statement could not be prepared.")
        }
        sqlite3_finalize(insertStatement)
    }
    
    func getAllMetadata() -> [String: (Double, Date)] {
        var result = [String: (Double, Date)]()
        let queryStatementString = "SELECT url, latency, last_check FROM video_metadata;"
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
