const std = @import("std");
const log = std.log.scoped(.insqlite_cli);

const mod = @import("sqlite");

/// CLI entry point. Accepts an optional database path and SQL string.
/// With SQL: executes the statement(s) — queries print rows, non-queries
/// run via `exec`. Without SQL: runs the built-in EMP/DEPT demo.
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
        try demo(&db);
    }
}

/// Seeds the classic Oracle EMP/DEPT schema into an in-memory database
/// and runs sample queries exercising exec, prepare, and bind parameters.
fn demo(db: *mod.SQLite) !void {
    try db.exec("BEGIN");

    // Create tables
    try db.exec(
        \\CREATE TABLE IF NOT EXISTS dept (
        \\    deptno INTEGER PRIMARY KEY,
        \\    dname  TEXT NOT NULL,
        \\    loc    TEXT
        \\);
        \\CREATE TABLE IF NOT EXISTS emp (
        \\    empno    INTEGER PRIMARY KEY,
        \\    ename    TEXT NOT NULL,
        \\    job      TEXT,
        \\    mgr      INTEGER,
        \\    hiredate TEXT,
        \\    sal      REAL,
        \\    comm     REAL,
        \\    deptno   INTEGER REFERENCES dept(deptno)
        \\);
    );

    // Seed departments
    try db.exec(
        \\INSERT OR IGNORE INTO dept VALUES (10, 'ACCOUNTING', 'NEW YORK');
        \\INSERT OR IGNORE INTO dept VALUES (20, 'RESEARCH',   'DALLAS');
        \\INSERT OR IGNORE INTO dept VALUES (30, 'SALES',      'CHICAGO');
        \\INSERT OR IGNORE INTO dept VALUES (40, 'OPERATIONS', 'BOSTON');
    );

    // Seed employees
    try db.exec(
        \\INSERT OR IGNORE INTO emp VALUES (7839, 'KING',   'PRESIDENT', NULL, '1981-11-17', 5000, NULL, 10);
        \\INSERT OR IGNORE INTO emp VALUES (7566, 'JONES',  'MANAGER',   7839, '1981-04-02', 2975, NULL, 20);
        \\INSERT OR IGNORE INTO emp VALUES (7698, 'BLAKE',  'MANAGER',   7839, '1981-05-01', 2850, NULL, 30);
        \\INSERT OR IGNORE INTO emp VALUES (7782, 'CLARK',  'MANAGER',   7839, '1981-06-09', 2450, NULL, 10);
        \\INSERT OR IGNORE INTO emp VALUES (7788, 'SCOTT',  'ANALYST',   7566, '1987-04-19', 3000, NULL, 20);
        \\INSERT OR IGNORE INTO emp VALUES (7902, 'FORD',   'ANALYST',   7566, '1981-12-03', 3000, NULL, 20);
        \\INSERT OR IGNORE INTO emp VALUES (7844, 'TURNER', 'SALESMAN',  7698, '1981-09-08', 1500, 0,    30);
        \\INSERT OR IGNORE INTO emp VALUES (7900, 'JAMES',  'CLERK',     7698, '1981-12-03', 950,  NULL, 30);
        \\INSERT OR IGNORE INTO emp VALUES (7934, 'MILLER', 'CLERK',     7782, '1982-01-23', 1300, NULL, 10);
    );

    try db.exec("COMMIT");

    std.debug.print("=== All Departments ===\n", .{});
    {
        var stmt = try db.prepare("SELECT deptno, dname, loc FROM dept ORDER BY deptno");
        defer stmt.deinit();
        while (try stmt.step()) {
            std.debug.print("{s} | {s} | {s}\n", .{
                stmt.columnText(0) orelse "NULL",
                stmt.columnText(1) orelse "NULL",
                stmt.columnText(2) orelse "NULL",
            });
        }
    }

    std.debug.print("\n=== All Employees ===\n", .{});
    {
        var stmt = try db.prepare("SELECT empno, ename, job, sal FROM emp ORDER BY empno");
        defer stmt.deinit();
        while (try stmt.step()) {
            std.debug.print("{s} | {s} | {s} | {s}\n", .{
                stmt.columnText(0) orelse "NULL",
                stmt.columnText(1) orelse "NULL",
                stmt.columnText(2) orelse "NULL",
                stmt.columnText(3) orelse "NULL",
            });
        }
    }

    std.debug.print("\n=== Employees in dept ? (bound: 20) ===\n", .{});
    {
        var stmt = try db.prepare("SELECT empno, ename, job, sal FROM emp WHERE deptno = ?");
        defer stmt.deinit();
        try stmt.bindInt(1, 20);
        while (try stmt.step()) {
            std.debug.print("{s} | {s} | {s} | {s}\n", .{
                stmt.columnText(0) orelse "NULL",
                stmt.columnText(1) orelse "NULL",
                stmt.columnText(2) orelse "NULL",
                stmt.columnText(3) orelse "NULL",
            });
        }
    }

    std.debug.print("\n=== Employees with sal > ? (bound: 2500.0) ===\n", .{});
    {
        var stmt = try db.prepare("SELECT ename, job, sal FROM emp WHERE sal > ? ORDER BY sal DESC");
        defer stmt.deinit();
        try stmt.bindDouble(1, 2500.0);
        while (try stmt.step()) {
            std.debug.print("{s} | {s} | {s}\n", .{
                stmt.columnText(0) orelse "NULL",
                stmt.columnText(1) orelse "NULL",
                stmt.columnText(2) orelse "NULL",
            });
        }
    }

    std.debug.print("\n=== Employees with job = ? (bound: 'MANAGER') ===\n", .{});
    {
        var stmt = try db.prepare("SELECT ename, deptno FROM emp WHERE job = ?");
        defer stmt.deinit();
        try stmt.bindText(1, "MANAGER");
        while (try stmt.step()) {
            std.debug.print("{s} | {s}\n", .{
                stmt.columnText(0) orelse "NULL",
                stmt.columnText(1) orelse "NULL",
            });
        }
    }

    std.debug.print("\ndemo complete\n", .{});
}
