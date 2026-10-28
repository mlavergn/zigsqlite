const std = @import("std");
const log = std.log.scoped(.zigsqlite_statement);
const mod = @import("module.zig");

/// A prepared SQL statement. Created by `SQLite.prepare` and must be
/// released with `deinit`. Holds a reference to the parent database
/// connection for error reporting.
pub const Statement = struct {
    const Self = @This();

    stmt: *mod.c.sqlite3_stmt,
    db: *mod.c.sqlite3,

    /// Creates a Statement wrapping raw SQLite C pointers.
    /// Called internally by `SQLite.prepare`.
    pub fn init(stmt: *mod.c.sqlite3_stmt, db: *mod.c.sqlite3) !Self {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        return Self{ .stmt = stmt, .db = db };
    }

    /// Releases the prepared statement resources via `sqlite3_finalize`.
    pub fn deinit(self: *Self) void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        _ = mod.c.sqlite3_finalize(self.stmt);
    }

    /// Advances to the next row. Returns `true` if a row is available
    /// for reading, `false` when execution is complete.
    pub fn step(self: *Self) !bool {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = mod.c.sqlite3_step(self.stmt);
        if (rc == mod.c.SQLITE_ROW) return true;
        if (rc == mod.c.SQLITE_DONE) return false;
        log.warn("step failed: {s}", .{mod.c.sqlite3_errmsg(self.db)});
        return mod.Errors.mapError(rc);
    }

    /// Returns the number of columns in the result set.
    pub fn columnCount(self: *const Self) u32 {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        return @intCast(mod.c.sqlite3_column_count(self.stmt));
    }

    /// Returns the value of column `col` as a 64-bit integer.
    pub fn columnInt(self: *const Self, col: u32) i64 {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        return mod.c.sqlite3_column_int64(self.stmt, @intCast(col));
    }

    /// Returns the value of column `col` as a Zig slice, or `null`
    /// if the column is SQL NULL.
    pub fn columnText(self: *const Self, col: u32) ?[]const u8 {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const idx: c_int = @intCast(col);
        const raw = mod.c.sqlite3_column_text(self.stmt, idx);
        if (raw == null) return null;
        const len: usize = @intCast(mod.c.sqlite3_column_bytes(self.stmt, idx));
        const ptr: [*]const u8 = @ptrCast(raw);
        return ptr[0..len];
    }

    /// Returns the value of column `col` as a 64-bit float.
    pub fn columnDouble(self: *const Self, col: u32) f64 {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        return mod.c.sqlite3_column_double(self.stmt, @intCast(col));
    }

    /// Returns the value of column `col` as a byte slice, or `null`
    /// if the column is SQL NULL.
    pub fn columnBlob(self: *const Self, col: u32) ?[]const u8 {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const idx: c_int = @intCast(col);
        const raw = mod.c.sqlite3_column_blob(self.stmt, idx);
        if (raw == null) return null;
        const len: usize = @intCast(mod.c.sqlite3_column_bytes(self.stmt, idx));
        const ptr: [*]const u8 = @ptrCast(raw);
        return ptr[0..len];
    }

    /// Binds a 64-bit integer value to parameter at `idx` (1-based).
    pub fn bindInt(self: *Self, idx: u32, val: i64) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = mod.c.sqlite3_bind_int64(self.stmt, @intCast(idx), val);
        if (rc != mod.c.SQLITE_OK) {
            log.err("bindInt failed: {s}", .{mod.c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Binds a text value to parameter at `idx` (1-based). Uses
    /// SQLITE_STATIC — the caller must ensure `val` outlives the
    /// statement execution (until step, reset, or deinit).
    pub fn bindText(self: *Self, idx: u32, val: []const u8) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = mod.c.sqlite3_bind_text(self.stmt, @intCast(idx), val.ptr, @intCast(val.len), null);
        if (rc != mod.c.SQLITE_OK) {
            log.err("bindText failed: {s}", .{mod.c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Binds a blob value to parameter at `idx` (1-based). Uses
    /// SQLITE_STATIC — the caller must ensure `val` outlives the
    /// statement execution (until step, reset, or deinit).
    pub fn bindBlob(self: *Self, idx: u32, val: []const u8) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = mod.c.sqlite3_bind_blob(self.stmt, @intCast(idx), val.ptr, @intCast(val.len), null);
        if (rc != mod.c.SQLITE_OK) {
            log.err("bindBlob failed: {s}", .{mod.c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Binds a 64-bit float value to parameter at `idx` (1-based).
    pub fn bindDouble(self: *Self, idx: u32, val: f64) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = mod.c.sqlite3_bind_double(self.stmt, @intCast(idx), val);
        if (rc != mod.c.SQLITE_OK) {
            log.err("bindDouble failed: {s}", .{mod.c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Binds SQL NULL to parameter at `idx` (1-based).
    pub fn bindNull(self: *Self, idx: u32) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = mod.c.sqlite3_bind_null(self.stmt, @intCast(idx));
        if (rc != mod.c.SQLITE_OK) {
            log.err("bindNull failed: {s}", .{mod.c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Resets the statement so it can be re-executed with new bindings.
    pub fn reset(self: *Self) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = mod.c.sqlite3_reset(self.stmt);
        if (rc != mod.c.SQLITE_OK) {
            log.err("reset failed: {s}", .{mod.c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Clears all parameter bindings, setting them to NULL.
    /// Call after `reset` to avoid stale bindings when reusing a statement.
    pub fn clearBindings(self: *Self) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = mod.c.sqlite3_clear_bindings(self.stmt);
        if (rc != mod.c.SQLITE_OK) {
            log.err("clearBindings failed: {s}", .{mod.c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }
};

// -----------------------------------------------------------------------------
// Unit Tests

test "step returns false on empty result" {
    var db = try mod.SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(id INTEGER)");
    var stmt = try db.prepare("SELECT * FROM t");
    defer stmt.deinit();
    try std.testing.expectEqual(false, try stmt.step());
}

test "columnInt" {
    var db = try mod.SQLite.init(":memory:");
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
    var db = try mod.SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val TEXT)");
    try db.exec("INSERT INTO t VALUES('hello')");
    var stmt = try db.prepare("SELECT val FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqualStrings("hello", stmt.columnText(0).?);
}

test "columnText returns null for SQL NULL" {
    var db = try mod.SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val TEXT)");
    try db.exec("INSERT INTO t VALUES(NULL)");
    var stmt = try db.prepare("SELECT val FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectEqual(@as(?[]const u8, null), stmt.columnText(0));
}

test "columnDouble" {
    var db = try mod.SQLite.init(":memory:");
    defer db.deinit();
    try db.exec("CREATE TABLE t(val REAL)");
    try db.exec("INSERT INTO t VALUES(3.14)");
    var stmt = try db.prepare("SELECT val FROM t");
    defer stmt.deinit();
    try std.testing.expect(try stmt.step());
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), stmt.columnDouble(0), 0.001);
}

test "bindInt" {
    var db = try mod.SQLite.init(":memory:");
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
    var db = try mod.SQLite.init(":memory:");
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
    var db = try mod.SQLite.init(":memory:");
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
    var db = try mod.SQLite.init(":memory:");
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
    var db = try mod.SQLite.init(":memory:");
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
