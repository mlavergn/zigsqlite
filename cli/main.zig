const std = @import("std");
const log = std.log.scoped(.zigsqlite_cli);
const cli = @import("module.zig");
const mod = @import("sqlite");

pub const std_options: std.Options = .{ .log_level = if (mod.is_debug) .debug else .info };

/// CLI entry point. Accepts an optional database path and SQL string.
/// With SQL: executes the statement(s) — queries print rows, non-queries
/// run via `exec`. Without SQL: runs the built-in EMP/DEPT demo.
pub fn main(init: std.process.Init.Minimal) !void {
    log.debug("{s}:{d} :: {s}", .{ @src().file, @src().line, @src().fn_name });
    var args = init.args.iterate();
    _ = args.next();

    const db_path = args.next() orelse ":memory:";
    const sql = args.next();

    log.info("opening: {s}", .{db_path});
    var db = try mod.SQLite.init(db_path);
    defer db.deinit();

    if (sql) |stmt_sql| {
        var stmt = try db.prepare(stmt_sql);
        defer stmt.deinit();

        const col_count = stmt.columnCount();
        if (col_count > 0) {
            // Query: step through result rows.
            while (try stmt.step()) {
                var col: u32 = 0;
                while (col < col_count) : (col += 1) {
                    if (col > 0) std.debug.print("|", .{});
                    if (stmt.columnText(col)) |text| {
                        std.debug.print("{s}", .{text});
                    } else {
                        std.debug.print("NULL", .{});
                    }
                }
                std.debug.print("\n", .{});
            }
        } else {
            // Non-query: step to execute the single statement.
            _ = try stmt.step();
            log.info("ok", .{});
        }
    } else {
        // No SQL argument: run the full demo
        var demo = try cli.Demo.init(&db);
        defer demo.deinit();
        try demo.run();
    }
}
