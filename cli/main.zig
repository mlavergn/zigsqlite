const std = @import("std");
const log = std.log.scoped(.insqlite3_cli);

const mod = @import("sqlite");

pub fn main() !void {
    var args = std.process.args();
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
            _ = try stmt.step();
            log.info("ok", .{});
        }
    } else {
        log.info("usage: insqlite3 <db_path> <sql>", .{});
    }
}
