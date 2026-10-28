const std = @import("std");
const log = std.log.scoped(.zigsqlite_extension);
const mod = @import("module.zig");

/// Extension function support for SQLite. Provides type aliases for the C
/// callback API and a registration method for scalar functions. Abstracts
/// the raw sqlite3_create_function interface behind Zig types.
pub const Extension = struct {
    const Self = @This();

    // -------------------------------------------------------------------------
    // Opaque C types used by extension function callbacks

    /// Opaque context passed to extension function callbacks.
    pub const Context = mod.c.sqlite3_context;

    /// Opaque value handle for reading function arguments.
    pub const Value = mod.c.sqlite3_value;

    // -------------------------------------------------------------------------
    // SQLite type discriminators

    pub const SQLITE_NULL = mod.c.SQLITE_NULL;
    pub const SQLITE_BLOB = mod.c.SQLITE_BLOB;
    pub const SQLITE_TEXT = mod.c.SQLITE_TEXT;
    pub const SQLITE_INTEGER = mod.c.SQLITE_INTEGER;
    pub const SQLITE_FLOAT = mod.c.SQLITE_FLOAT;

    // -------------------------------------------------------------------------
    // Function registration flags

    pub const SQLITE_UTF8 = mod.c.SQLITE_UTF8;
    pub const SQLITE_DETERMINISTIC = mod.c.SQLITE_DETERMINISTIC;

    // -------------------------------------------------------------------------
    // Callback function type

    /// Extension scalar function callback signature.
    pub const ScalarFn = *const fn (?*Context, c_int, [*c]?*Value) callconv(.c) void;

    /// C-compatible free function type for result callbacks.
    pub const DestroyFn = *const fn (?*anyopaque) callconv(.c) void;

    /// No-op constructor.
    pub fn init() !Self {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        return Self{};
    }

    /// No-op destructor.
    pub fn deinit(self: *Self) void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        _ = self;
    }

    // -------------------------------------------------------------------------
    // Value accessors (used inside extension function callbacks)

    /// Returns the type discriminator for a value argument.
    pub const valueType = mod.c.sqlite3_value_type;

    /// Returns a pointer to the blob data for a value argument.
    pub const valueBlob = mod.c.sqlite3_value_blob;

    /// Returns a pointer to the text data for a value argument.
    pub const valueText = mod.c.sqlite3_value_text;

    /// Returns the byte length of a blob or text value argument.
    pub const valueBytes = mod.c.sqlite3_value_bytes;

    // -------------------------------------------------------------------------
    // Result setters (used inside extension function callbacks)

    /// Sets the function result to a blob value.
    pub const resultBlob = mod.c.sqlite3_result_blob;

    /// Sets the function result to a text value.
    pub const resultText = mod.c.sqlite3_result_text;

    /// Sets the function result to SQL NULL.
    pub const resultNull = mod.c.sqlite3_result_null;

    /// Sets the function result to an error with a message.
    pub const resultError = mod.c.sqlite3_result_error;

    /// Sets the function result to an out-of-memory error.
    pub const resultErrorNomem = mod.c.sqlite3_result_error_nomem;

    /// Returns the database connection handle associated with a callback context.
    pub const contextDbHandle = mod.c.sqlite3_context_db_handle;

    // -------------------------------------------------------------------------
    // Raw C API (for shell integration and auto-extension registration)

    /// Opaque raw database connection handle (sqlite3*).
    pub const Db = mod.c.sqlite3;

    /// SQLite success result code.
    pub const SQLITE_OK = mod.c.SQLITE_OK;

    /// Raw sqlite3_create_function for use with raw db handles (e.g. auto-extension callbacks).
    pub const createFunction = mod.c.sqlite3_create_function;

    /// Registers an auto-extension that runs on every new connection.
    pub const autoExtension = mod.c.sqlite3_auto_extension;

    /// Auto-extension entry point signature: called on every new connection.
    pub const AutoExtensionFn = *const fn (?*Db, ?*?*u8, ?*const anyopaque) callconv(.c) c_int;

    // -------------------------------------------------------------------------
    // Registration

    /// Registers a scalar SQL function on the given database connection.
    pub fn register(db: *mod.SQLite, name: [*:0]const u8, n_arg: c_int, flags: c_int, user_data: ?*anyopaque, func: ScalarFn) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const handle = db.db orelse return error.SQLiteMisuse;
        const rc = mod.c.sqlite3_create_function(handle, name, n_arg, flags, user_data, func, null, null);
        if (rc != mod.c.SQLITE_OK) {
            log.err("register failed for {s}: {s}", .{ name, mod.c.sqlite3_errmsg(handle) });
            return mod.Errors.mapError(rc);
        }
    }
};

// -----------------------------------------------------------------------------
// Unit Tests

test "Extension init/deinit" {
    var ext = try Extension.init();
    ext.deinit();
}
