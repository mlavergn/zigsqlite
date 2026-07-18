const builtin = @import("builtin");
const std = @import("std");

const zon = @import("build.zig.zon");

/// Options for creating a SQLite module with optional static extensions.
pub const Config = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    /// C source files for statically linked extensions.
    /// Compile extension sources with `-DSQLITE_CORE` when the extension
    /// supports it, so it links directly rather than through the loadable
    /// extension interface.
    extension_c_source_files: []const std.Build.Module.CSourceFile = &.{},
    /// Additional include paths (e.g. for extension headers).
    extension_include_paths: []const std.Build.LazyPath = &.{},
};

/// Creates a SQLite module suitable for use as an import in consumer code.
/// When used as a dependency:
///
/// ```zig
/// const dep = b.dependency("zigsqlite", .{});
/// const zigsqlite = @import("zigsqlite");
/// const sqlite_mod = zigsqlite.createModule(dep, .{
///     .target = target,
///     .optimize = optimize,
///     .extension_c_source_files = &.{
///         .{ .file = b.path("ext/my_extension.c"), .flags = &.{"-DSQLITE_CORE"} },
///     },
/// });
/// my_mod.addImport("sqlite", sqlite_mod);
/// ```
pub fn createModule(dep: *std.Build.Dependency, options: Config) *std.Build.Module {
    return createSqliteModule(dep.builder, options);
}

/// Creates the core SQLite module rooted at src/module.zig. Compiles the
/// SQLite amalgamation C source and links libc. Optional extension C
/// sources and include paths are added when provided.
fn createSqliteModule(b: *std.Build, options: Config) *std.Build.Module {
    const mod = b.createModule(.{
        .target = options.target,
        .optimize = options.optimize,
        .root_source_file = b.path("src/module.zig"),
        .link_libc = true,
    });
    mod.addIncludePath(b.path("sqlite"));
    mod.addCSourceFile(.{
        .file = b.path("sqlite/sqlite3.c"),
        .flags = &[_][]const u8{
            "-fno-sanitize=undefined",
        },
    });
    for (options.extension_include_paths) |path| {
        mod.addIncludePath(path);
    }
    for (options.extension_c_source_files) |src| {
        mod.addCSourceFile(src);
    }
    return mod;
}

pub fn build(b: *std.Build) !void {
    const name = @tagName(zon.name);
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
        .cpu_features_add = std.Target.aarch64.featureSet(&[_]std.Target.aarch64.Feature{
            .pauth,
        }),
    });

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    // src/module.zig — library barrel (SQLite + Statement + C FFI)
    const sqlite_mod = createSqliteModule(b, .{
        .target = target,
        .optimize = optimize,
    });

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

    // demo CLI — imports library module as "sqlite"
    const demo_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("cli/main.zig"),
    });
    demo_mod.addImport("sqlite", sqlite_mod);

    const demo = b.addExecutable(.{
        .name = "demo",
        .root_module = demo_mod,
    });
    b.installArtifact(demo);

    // Test step — runs unit tests via module.zig (refAllDecls discovers all)
    const test_mod = createSqliteModule(b, .{
        .target = target,
        .optimize = optimize,
    });

    const unit_tests = b.addTest(.{
        .root_module = test_mod,
    });
    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
