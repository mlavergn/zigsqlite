# Sample: insqlite Usage

Complete examples demonstrating the insqlite Zig API for opening databases, executing SQL, querying rows, binding parameters, and reusing prepared statements.

## Create a Table and Insert Rows

```zig
const std = @import("std");
const mod = @import("insqlite");

pub fn main() !void {
    var db = try mod.SQLite.init(":memory:");
    defer db.deinit();

    try db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)");
    try db.exec(
        \\INSERT INTO users VALUES (1, 'Alice', 'alice@example.com');
        \\INSERT INTO users VALUES (2, 'Bob', 'bob@example.com');
        \\INSERT INTO users VALUES (3, 'Carol', 'carol@example.com');
    );

    std.debug.print("3 users inserted\n", .{});
}
```

## Query Rows and Read Columns

```zig
const std = @import("std");
const mod = @import("insqlite");

pub fn main() !void {
    var db = try mod.SQLite.init(":memory:");
    defer db.deinit();

    try db.exec("CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT, price REAL)");
    try db.exec(
        \\INSERT INTO products VALUES (1, 'Widget', 9.99);
        \\INSERT INTO products VALUES (2, 'Gadget', 24.50);
        \\INSERT INTO products VALUES (3, 'Gizmo', 14.75);
    );

    var stmt = try db.prepare("SELECT id, name, price FROM products ORDER BY price DESC");
    defer stmt.deinit();

    while (try stmt.step()) {
        const id = stmt.columnInt(0);
        const name = stmt.columnText(1) orelse "NULL";
        const price = stmt.columnDouble(2);
        std.debug.print("{d} | {s} | {d:.2}\n", .{ id, name, price });
    }
}
```

## Bind Parameters to a Prepared Statement

```zig
const std = @import("std");
const mod = @import("insqlite");

pub fn main() !void {
    var db = try mod.SQLite.init(":memory:");
    defer db.deinit();

    try db.exec("CREATE TABLE logs (ts TEXT, level TEXT, message TEXT)");

    // Insert with bound parameters to avoid SQL injection
    var ins = try db.prepare("INSERT INTO logs VALUES (?, ?, ?)");
    defer ins.deinit();

    try ins.bindText(1, "2026-04-04T10:00:00Z");
    try ins.bindText(2, "INFO");
    try ins.bindText(3, "Application started");
    _ = try ins.step();

    // Reset and reuse for a second row
    try ins.reset();
    try ins.clearBindings();
    try ins.bindText(1, "2026-04-04T10:05:00Z");
    try ins.bindText(2, "ERROR");
    try ins.bindText(3, "Connection refused");
    _ = try ins.step();

    var sel = try db.prepare("SELECT ts, level, message FROM logs WHERE level = ?");
    defer sel.deinit();

    try sel.bindText(1, "ERROR");
    while (try sel.step()) {
        std.debug.print("[{s}] {s}: {s}\n", .{
            sel.columnText(0) orelse "NULL",
            sel.columnText(1) orelse "NULL",
            sel.columnText(2) orelse "NULL",
        });
    }
}
```

## Handle NULL Values and Mixed Column Types

```zig
const std = @import("std");
const mod = @import("insqlite");

pub fn main() !void {
    var db = try mod.SQLite.init(":memory:");
    defer db.deinit();

    try db.exec(
        \\CREATE TABLE contacts (
        \\    id    INTEGER PRIMARY KEY,
        \\    name  TEXT NOT NULL,
        \\    phone TEXT,
        \\    score REAL
        \\);
        \\INSERT INTO contacts VALUES (1, 'Alice', '+1-555-0100', 4.8);
        \\INSERT INTO contacts VALUES (2, 'Bob', NULL, 3.2);
        \\INSERT INTO contacts VALUES (3, 'Carol', '+1-555-0102', NULL);
    );

    var stmt = try db.prepare("SELECT name, phone, score FROM contacts ORDER BY id");
    defer stmt.deinit();

    while (try stmt.step()) {
        const name = stmt.columnText(0) orelse "NULL";
        const phone = stmt.columnText(1) orelse "(no phone)";
        // columnText returns null for SQL NULL; columnDouble returns 0.0
        const score_text = stmt.columnText(2);
        if (score_text) |s| {
            std.debug.print("{s} | {s} | {s}\n", .{ name, phone, s });
        } else {
            std.debug.print("{s} | {s} | (no score)\n", .{ name, phone });
        }
    }
}
```

## Use a File-Backed Database with Transactions

```zig
const std = @import("std");
const mod = @import("insqlite");

pub fn main() !void {
    var db = try mod.SQLite.init("sample.db");
    defer db.deinit();

    // WAL mode for better concurrent read performance
    try db.exec("PRAGMA journal_mode=WAL");

    try db.exec("CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT)");

    // Wrap multiple writes in a transaction for atomicity
    try db.exec("BEGIN");
    try db.exec(
        \\INSERT OR REPLACE INTO kv VALUES ('host', 'db.example.com');
        \\INSERT OR REPLACE INTO kv VALUES ('port', '5432');
        \\INSERT OR REPLACE INTO kv VALUES ('name', 'myapp_prod');
    );
    try db.exec("COMMIT");

    var stmt = try db.prepare("SELECT key, value FROM kv WHERE key = ?");
    defer stmt.deinit();

    try stmt.bindText(1, "host");
    if (try stmt.step()) {
        std.debug.print("{s} = {s}\n", .{
            stmt.columnText(0) orelse "NULL",
            stmt.columnText(1) orelse "NULL",
        });
    }
}
```
