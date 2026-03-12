const builtin = @import("builtin");
const std = @import("std");

const zon = @import("build.zig.zon");

pub fn build(b: *std.Build) !void {
    const name = @tagName(zon.name);
    const semVer = try std.SemanticVersion.parse(zon.version);

    std.log.info("Version: {s}", .{zon.version});
    std.log.info("SemVersion: {any}", .{semVer});

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
        .cpu_features_add = std.Target.aarch64.featureSet(&[_]std.Target.aarch64.Feature{
            .pauth,
        }),
    });

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    // src/sqlite.zig — SQLite implementation (C FFI + Zig API)
    const src_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/sqlite.zig"),
        .link_libc = true,
    });
    src_mod.addIncludePath(b.path("sqlite"));
    src_mod.addCSourceFile(.{
        .file = b.path("sqlite/sqlite3.c"),
        .flags = &[_][]const u8{
            "-fPIC",
            "-fno-sanitize=undefined",
        },
    });

    // src/module.zig — barrel re-export of sqlite.zig
    const sqlite_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/module.zig"),
    });
    sqlite_mod.addImport("sqlite", src_mod);

    // SQLite library artifact
    const lib = b.addLibrary(.{
        .name = name,
        .linkage = .static,
        .root_module = sqlite_mod,
    });
    b.installArtifact(lib);

    // sqlite3 CLI (standard C shell)
    const sqlite3_cli_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    sqlite3_cli_mod.addIncludePath(b.path("sqlite"));
    sqlite3_cli_mod.addCSourceFile(.{
        .file = b.path("sqlite/sqlite3.c"),
        .flags = &[_][]const u8{
            "-fPIC",
            "-fno-sanitize=undefined",
        },
    });
    sqlite3_cli_mod.addCSourceFile(.{
        .file = b.path("sqlite/shell.c"),
    });

    const sqlite3_cli = b.addExecutable(.{
        .name = "sqlite3",
        .root_module = sqlite3_cli_mod,
    });
    b.installArtifact(sqlite3_cli);

    // insqlite CLI — imports src module as "sqlite"
    const cli_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("cli/main.zig"),
    });
    cli_mod.addImport("sqlite", src_mod);

    const bin = b.addExecutable(.{
        .name = name,
        .root_module = cli_mod,
    });
    b.installArtifact(bin);
}
