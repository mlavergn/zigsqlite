const std = @import("std");
const log = std.log.scoped(.zigsqlite_sqlite);
const mod = @import("module.zig");

/// Zig wrapper around a SQLite database connection. Manages the
/// lifecycle of the underlying `sqlite3*` handle and provides
/// methods for executing SQL and preparing statements.
pub const SQLite = struct {
    const Self = @This();

    db: ?*mod.c.sqlite3 = null,

    /// Opens a database file at `path`. Use ":memory:" for an
    /// in-memory database. The connection must be released with `deinit`.
    pub fn init(path: [*:0]const u8) !Self {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        var db: ?*mod.c.sqlite3 = null;
        const rc = mod.c.sqlite3_open(path, &db);
        if (rc != mod.c.SQLITE_OK) {
            if (db) |d| _ = mod.c.sqlite3_close(d);
            return mod.Errors.mapError(rc);
        }
        return Self{ .db = db };
    }

    /// Closes the database connection and releases all resources.
    /// Uses `sqlite3_close_v2` which defers closing until all
    /// prepared statements are finalized.
    pub fn deinit(self: *Self) void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        if (self.db) |db| {
            _ = mod.c.sqlite3_close_v2(db);
            self.db = null;
        }
    }

    /// Registers a statically linked extension to be automatically loaded
    /// on every new database connection. Must be called before `init`.
    /// The entry_point is the extension's init function, e.g.:
    ///
    ///     extern fn sqlite3_uuid_init() callconv(.c) void;
    ///     try SQLite.registerExtension(@ptrCast(&sqlite3_uuid_init));
    ///
    pub fn registerExtension(entry_point: *const fn () callconv(.c) void) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = mod.c.sqlite3_auto_extension(entry_point);
        if (rc != mod.c.SQLITE_OK) return mod.Errors.mapError(rc);
    }

    /// Removes all previously registered auto-extensions.
    pub fn resetExtensions() void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        mod.c.sqlite3_reset_auto_extension();
    }

    /// Executes one or more semicolon-separated SQL statements that
    /// return no rows (e.g. CREATE TABLE, INSERT, UPDATE, DELETE,
    /// pragma statements, or DDL scripts).
    pub fn exec(self: *Self, sql: [*:0]const u8) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const db = self.db orelse return error.SQLiteMisuse;
        const rc = mod.c.sqlite3_exec(db, sql, null, null, null);
        if (rc != mod.c.SQLITE_OK) {
            log.err("exec failed: {s}", .{mod.c.sqlite3_errmsg(db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Compiles a SQL statement and returns a `Statement` that can be
    /// stepped through to read result rows. The caller must call
    /// `Statement.deinit` when finished.
    pub fn prepare(self: *Self, sql: [*:0]const u8) !mod.Statement {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const db = self.db orelse return error.SQLiteMisuse;
        var stmt: ?*mod.c.sqlite3_stmt = null;
        const rc = mod.c.sqlite3_prepare_v2(db, sql, -1, &stmt, null);
        if (rc != mod.c.SQLITE_OK) {
            log.err("prepare failed: {s}", .{mod.c.sqlite3_errmsg(db)});
            return mod.Errors.mapError(rc);
        }
        return mod.Statement.init(stmt orelse return mod.Errors.mapError(mod.c.SQLITE_ERROR), db);
    }
};

// -----------------------------------------------------------------------------
// Unit Tests

test "init and deinit" {
    var db = try SQLite.init(":memory:");
    db.deinit();
}

test "exec create table and insert" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)");
    try db.exec("INSERT INTO t VALUES(1, 'hello')");
}

test "exec multiple semicolon-separated statements" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER); INSERT INTO t VALUES(1); INSERT INTO t VALUES(2)");
    var stmt = try db.prepare("SELECT count(*) FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqual(@as(i64, 2), stmt.columnInt(0));
}

test "prepare and columnCount" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(a INTEGER, b TEXT, c REAL)");
    var stmt = try db.prepare("SELECT a, b, c FROM t");
    defer stmt.deinit();
    try std.testing.expectEqual(@as(u32, 3), stmt.columnCount());
}
