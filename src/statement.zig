const std = @import("std");
const log = std.log.scoped(.insqlite_statement);

const mod = @import("module.zig");
const c = mod.c;

/// A prepared SQL statement. Created by `SQLite.prepare` and must be
/// released with `deinit`. Holds a reference to the parent database
/// connection for error reporting.
pub const Statement = struct {
    const Self = @This();

    stmt: *c.sqlite3_stmt,
    db: *c.sqlite3,

    /// Creates a Statement wrapping raw SQLite C pointers.
    /// Called internally by `SQLite.prepare`.
    pub fn init(stmt: *c.sqlite3_stmt, db: *c.sqlite3) Self {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        return Self{ .stmt = stmt, .db = db };
    }

    /// Releases the prepared statement resources via `sqlite3_finalize`.
    pub fn deinit(self: *Self) void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        _ = c.sqlite3_finalize(self.stmt);
    }

    /// Advances to the next row. Returns `true` if a row is available
    /// for reading, `false` when execution is complete.
    pub fn step(self: *Self) !bool {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_step(self.stmt);
        if (rc == c.SQLITE_ROW) return true;
        if (rc == c.SQLITE_DONE) return false;
        log.warn("step failed: {s}", .{c.sqlite3_errmsg(self.db)});
        return mod.Errors.mapError(rc);
    }

    /// Returns the number of columns in the result set.
    pub fn columnCount(self: *const Self) u32 {
        return @intCast(c.sqlite3_column_count(self.stmt));
    }

    /// Returns the value of column `col` as a 64-bit integer.
    pub fn columnInt(self: *const Self, col: u32) i64 {
        return c.sqlite3_column_int64(self.stmt, @intCast(col));
    }

    /// Returns the value of column `col` as a Zig slice, or `null`
    /// if the column is SQL NULL.
    pub fn columnText(self: *const Self, col: u32) ?[]const u8 {
        const idx: c_int = @intCast(col);
        const raw = c.sqlite3_column_text(self.stmt, idx);
        if (raw == null) return null;
        const len: usize = @intCast(c.sqlite3_column_bytes(self.stmt, idx));
        const ptr: [*]const u8 = @ptrCast(raw);
        return ptr[0..len];
    }

    /// Returns the value of column `col` as a 64-bit float.
    pub fn columnDouble(self: *const Self, col: u32) f64 {
        return c.sqlite3_column_double(self.stmt, @intCast(col));
    }

    /// Returns the value of column `col` as a byte slice, or `null`
    /// if the column is SQL NULL.
    pub fn columnBlob(self: *const Self, col: u32) ?[]const u8 {
        const idx: c_int = @intCast(col);
        const raw = c.sqlite3_column_blob(self.stmt, idx);
        if (raw == null) return null;
        const len: usize = @intCast(c.sqlite3_column_bytes(self.stmt, idx));
        const ptr: [*]const u8 = @ptrCast(raw);
        return ptr[0..len];
    }

    /// Binds a 64-bit integer value to parameter at `idx` (1-based).
    pub fn bindInt(self: *Self, idx: u32, val: i64) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_bind_int64(self.stmt, @intCast(idx), val);
        if (rc != c.SQLITE_OK) {
            log.err("bindInt failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Binds a text value to parameter at `idx` (1-based). Uses
    /// SQLITE_STATIC — the caller must ensure `val` outlives the
    /// statement execution (until step, reset, or deinit).
    pub fn bindText(self: *Self, idx: u32, val: []const u8) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_bind_text(self.stmt, @intCast(idx), val.ptr, @intCast(val.len), null);
        if (rc != c.SQLITE_OK) {
            log.err("bindText failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Binds a blob value to parameter at `idx` (1-based). Uses
    /// SQLITE_STATIC — the caller must ensure `val` outlives the
    /// statement execution (until step, reset, or deinit).
    pub fn bindBlob(self: *Self, idx: u32, val: []const u8) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_bind_blob(self.stmt, @intCast(idx), val.ptr, @intCast(val.len), null);
        if (rc != c.SQLITE_OK) {
            log.err("bindBlob failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Binds a 64-bit float value to parameter at `idx` (1-based).
    pub fn bindDouble(self: *Self, idx: u32, val: f64) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_bind_double(self.stmt, @intCast(idx), val);
        if (rc != c.SQLITE_OK) {
            log.err("bindDouble failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Binds SQL NULL to parameter at `idx` (1-based).
    pub fn bindNull(self: *Self, idx: u32) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_bind_null(self.stmt, @intCast(idx));
        if (rc != c.SQLITE_OK) {
            log.err("bindNull failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Resets the statement so it can be re-executed with new bindings.
    pub fn reset(self: *Self) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_reset(self.stmt);
        if (rc != c.SQLITE_OK) {
            log.err("reset failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }

    /// Clears all parameter bindings, setting them to NULL.
    /// Call after `reset` to avoid stale bindings when reusing a statement.
    pub fn clearBindings(self: *Self) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const rc = c.sqlite3_clear_bindings(self.stmt);
        if (rc != c.SQLITE_OK) {
            log.err("clearBindings failed: {s}", .{c.sqlite3_errmsg(self.db)});
            return mod.Errors.mapError(rc);
        }
    }
};
