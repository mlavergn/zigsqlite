const std = @import("std");
const log = std.log.scoped(.insqlite_extension);

const mod = @import("module.zig");
const c = mod.c;

/// Extension function support for SQLite. Provides type aliases for the C
/// callback API and a registration method for scalar functions. Abstracts
/// the raw sqlite3_create_function interface behind Zig types.
pub const Extension = struct {
    const Self = @This();

    // -------------------------------------------------------------------------
    // Opaque C types used by extension function callbacks

    /// Opaque context passed to extension function callbacks.
    pub const Context = c.sqlite3_context;

    /// Opaque value handle for reading function arguments.
    pub const Value = c.sqlite3_value;

    // -------------------------------------------------------------------------
    // SQLite type discriminators

    pub const SQLITE_NULL = c.SQLITE_NULL;
    pub const SQLITE_BLOB = c.SQLITE_BLOB;
    pub const SQLITE_TEXT = c.SQLITE_TEXT;
    pub const SQLITE_INTEGER = c.SQLITE_INTEGER;
    pub const SQLITE_FLOAT = c.SQLITE_FLOAT;

    // -------------------------------------------------------------------------
    // Function registration flags

    pub const SQLITE_UTF8 = c.SQLITE_UTF8;
    pub const SQLITE_DETERMINISTIC = c.SQLITE_DETERMINISTIC;

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
        _ = self;
    }

    // -------------------------------------------------------------------------
    // Value accessors (used inside extension function callbacks)

    /// Returns the type discriminator for a value argument.
    pub const valueType = c.sqlite3_value_type;

    /// Returns a pointer to the blob data for a value argument.
    pub const valueBlob = c.sqlite3_value_blob;

    /// Returns a pointer to the text data for a value argument.
    pub const valueText = c.sqlite3_value_text;

    /// Returns the byte length of a blob or text value argument.
    pub const valueBytes = c.sqlite3_value_bytes;

    // -------------------------------------------------------------------------
    // Result setters (used inside extension function callbacks)

    /// Sets the function result to a blob value.
    pub const resultBlob = c.sqlite3_result_blob;

    /// Sets the function result to a text value.
    pub const resultText = c.sqlite3_result_text;

    /// Sets the function result to SQL NULL.
    pub const resultNull = c.sqlite3_result_null;

    /// Sets the function result to an error with a message.
    pub const resultError = c.sqlite3_result_error;

    /// Sets the function result to an out-of-memory error.
    pub const resultErrorNomem = c.sqlite3_result_error_nomem;

    // -------------------------------------------------------------------------
    // Registration

    /// Registers a scalar SQL function on the given database connection.
    pub fn register(
        db: *mod.SQLite,
        name: [*:0]const u8,
        n_arg: c_int,
        flags: c_int,
        user_data: ?*anyopaque,
        func: ScalarFn,
    ) !void {
        log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
        const handle = db.db orelse return error.SQLiteMisuse;
        const rc = c.sqlite3_create_function(handle, name, n_arg, flags, user_data, func, null, null);
        if (rc != c.SQLITE_OK) {
            log.err("register failed for {s}: {s}", .{ name, c.sqlite3_errmsg(handle) });
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
