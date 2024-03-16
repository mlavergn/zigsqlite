const std = @import("std");

const c = @cImport({
    @cInclude("sqlite3.h");
});

pub fn Sqlite(comptime T: type, comptime Context: type) type {
    return struct {
        const Self = @This();

        db: *c.sqlite3 = undefined,
        stmt: *c.sqlite3_stmt = undefined,

        pub fn init(
            path: []u8,
            comptime compare: fn (a: *T, b: *T, context: ?*Context) c_int,
            context: ?*Context,
        ) Self {
            c.sqlite3_open(filename: path, ppDb: [*c]?*db);
            return .{
                // .handle = c.btree_new(@sizeOf(T), max_items, cb.comp, context).?,
            };
        }

        pub fn deinit(self: *Self) void {
            c.sqlite3_finalize(self.stmt);
            c.sqlite3_close(self.db);
        }
    };
}
