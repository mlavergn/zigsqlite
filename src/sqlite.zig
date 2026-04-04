const std = @import("std");
const log = std.log.scoped(.insqlite_sqlite);

const mod = @import("module.zig");

pub const c = @cImport({
    @cInclude("sqlite3.h");
});

/// Zig wrapper around a SQLite database connection. Manages the
/// lifecycle of the underlying `sqlite3*` handle and provides
/// methods for executing SQL and preparing statements.
pub const SQLite = struct {
    const Self = @This();

    db: ?*c.sqlite3 = null,

    /// Registers a statically linked extension to be automatically loaded
    /// on every new database connection. Must be called before `init`.
    /// The entry_point is the extension's init function, e.g.:
    ///
    ///     extern fn sqlite3_uuid_init() callconv(.c) void;
    ///     try SQLite.registerExtension(@ptrCast(&sqlite3_uuid_init));
    ///
    pub fn registerExtension(entry_point: *const fn () callconv(.c) void) !void {
        const rc = c.sqlite3_auto_extension(entry_point);
        if (rc != c.SQLITE_OK) return mod.Errors.mapError(rc);
    }

    /// Removes all previously registered auto-extensions.
    pub fn resetExtensions() void {
        c.sqlite3_reset_auto_extension();
    }

    /// Opens a database file at `path`. Use ":memory:" for an
    /// in-memory database. The connection must be released with `deinit`.
    pub fn init(path: [*:0]const u8) !Self {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        var db: ?*c.sqlite3 = null;
        const rc = c.sqlite3_open(path, &db);
        if (rc != c.SQLITE_OK) {
            if (db) |d| _ = c.sqlite3_close(d);
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
            _ = c.sqlite3_close_v2(db);
            self.db = null;
        }
    }

    /// Executes one or more semicolon-separated SQL statements that
    /// return no rows (e.g. CREATE TABLE, INSERT, UPDATE, DELETE,
    /// pragma statements, or DDL scripts).
    pub fn exec(self: *Self, sql: [*:0]const u8) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const db = self.db orelse return error.SQLiteMisuse;
        const rc = c.sqlite3_exec(db, sql, null, null, null);
        if (rc != c.SQLITE_OK) {
            log.err("exec failed: {s}", .{c.sqlite3_errmsg(db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Compiles a SQL statement and returns a `Statement` that can be
    /// stepped through to read result rows. The caller must call
    /// `Statement.deinit` when finished.
    pub fn prepare(self: *Self, sql: [*:0]const u8) !mod.Statement {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const db = self.db orelse return error.SQLiteMisuse;
        var stmt: ?*c.sqlite3_stmt = null;
        const rc = c.sqlite3_prepare_v2(db, sql, -1, &stmt, null);
        if (rc != c.SQLITE_OK) {
            log.err("prepare failed: {s}", .{c.sqlite3_errmsg(db)});
            return mod.Errors.mapError(rc);
        }
        return mod.Statement.init(stmt orelse return mod.Errors.mapError(c.SQLITE_ERROR), db);
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

test "step returns false on empty result" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER)");
    var stmt = try db.prepare("SELECT * FROM t");
    defer stmt.deinit();
    try std.testing.expectEqual(false, try stmt.step());
}

test "columnInt" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val INTEGER)");
    try db.exec("INSERT INTO t VALUES(42)");
    var stmt = try db.prepare("SELECT val FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqual(@as(i64, 42), stmt.columnInt(0));
    try std.testing.expectEqual(false, try stmt.step());
}

test "columnText" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val TEXT)");
    try db.exec("INSERT INTO t VALUES('hello')");
    var stmt = try db.prepare("SELECT val FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqualStrings("hello", stmt.columnText(0).?);
}

test "columnText returns null for SQL NULL" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val TEXT)");
    try db.exec("INSERT INTO t VALUES(NULL)");
    var stmt = try db.prepare("SELECT val FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqual(@as(?[]const u8, null), stmt.columnText(0));
}

test "columnDouble" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val REAL)");
    try db.exec("INSERT INTO t VALUES(3.14)");
    var stmt = try db.prepare("SELECT val FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), stmt.columnDouble(0), 0.001);
}

test "bindInt" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER, val TEXT)");
    try db.exec("INSERT INTO t VALUES(1, 'a'); INSERT INTO t VALUES(2, 'b')");
    var stmt = try db.prepare("SELECT val FROM t WHERE id = ?");
    defer stmt.deinit();
    try stmt.bindInt(1, 2);
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqualStrings("b", stmt.columnText(0).?);
    try std.testing.expectEqual(false, try stmt.step());
}

test "bindText" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER, name TEXT)");
    try db.exec("INSERT INTO t VALUES(1, 'alice'); INSERT INTO t VALUES(2, 'bob')");
    var stmt = try db.prepare("SELECT id FROM t WHERE name = ?");
    defer stmt.deinit();
    try stmt.bindText(1, "bob");
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqual(@as(i64, 2), stmt.columnInt(0));
}

test "bindDouble" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val REAL)");
    try db.exec("INSERT INTO t VALUES(1.5); INSERT INTO t VALUES(2.5); INSERT INTO t VALUES(3.5)");
    var stmt = try db.prepare("SELECT val FROM t WHERE val > ? ORDER BY val");
    defer stmt.deinit();
    try stmt.bindDouble(1, 2.0);
    try std.testing.expect(try stmt.step());
    try std.testing.expectApproxEqAbs(@as(f64, 2.5), stmt.columnDouble(0), 0.001);
    try std.testing.expect(try stmt.step());
    try std.testing.expectApproxEqAbs(@as(f64, 3.5), stmt.columnDouble(0), 0.001);
    try std.testing.expectEqual(false, try stmt.step());
}

test "bindNull" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val TEXT)");
    var ins = try db.prepare("INSERT INTO t VALUES(?)");
    try ins.bindNull(1);
    try std.testing.expectEqual(false, try ins.step());
    ins.deinit();
    var sel = try db.prepare("SELECT val FROM t");
    defer sel.deinit();
    try std.testing.expect(try sel.step());
    try std.testing.expectEqual(@as(?[]const u8, null), sel.columnText(0));
}

test "reset and clearBindings" {
    var db = try SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER, name TEXT)");
    try db.exec("INSERT INTO t VALUES(1, 'a'); INSERT INTO t VALUES(2, 'b')");
    var stmt = try db.prepare("SELECT name FROM t WHERE id = ?");
    defer stmt.deinit();

    // First execution
    try stmt.bindInt(1, 1);
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqualStrings("a", stmt.columnText(0).?);

    // Reset, clear, re-bind
    try stmt.reset();
    try stmt.clearBindings();
    try stmt.bindInt(1, 2);
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqualStrings("b", stmt.columnText(0).?);
}
