const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const SQLite = struct {
    db: ?*c.sqlite3 = null,

    pub fn open(path: [*:0]const u8) !SQLite {
        var db: ?*c.sqlite3 = null;
        const rc = c.sqlite3_open(path, &db);
        if (rc != c.SQLITE_OK) {
            if (db) |d| c.sqlite3_close(d);
            return error.SQLiteOpenFailed;
        }
        return SQLite{ .db = db };
    }

    pub fn close(self: *SQLite) void {
        if (self.db) |db| {
            _ = c.sqlite3_close(db);
            self.db = null;
        }
    }
};
