const builtin = @import("builtin");
const std = @import("std");

const is_zig_0_11 = std.mem.eql(u8, builtin.zig_version_string, "0.11.0");

// const target = std.zig.CrossTarget{ .os_tag = .linux, .cpu_arch = .x86_64 };
// const target = std.zig.CrossTarget{ .os_tag = .macos, .cpu_arch = .aarch64 };

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // const mode = b.standardReleaseOptions();

    const bin = b.addExecutable(.{
        .name = "sqlite3",
        .root_source_file = .{ .path = "src/shell.c" },
    });
    bin.addIncludePath(.{ .path = "src" });
    // bin.addCSourceFiles(&[_][]const u8{"src/sqlite3.c"}, &[_][]const u8{ "-g", "-O3" });

    const lib = b.addStaticLibrary(.{ .name = "sqlite3", .root_source_file = .{ .path = "src/sqlite3.c" }, .optimize = optimize, .target = target });

    b.installArtifact(lib);

    bin.linkLibrary(lib);

    const install = b.addInstallArtifact(bin, .{});
    b.default_step.dependOn(&install.step);
}

pub const GitCloneStep = struct {
    pub fn create(b: *std.build.Builder, url: string, repopath: string) *GitExactStep {
        var clonestep = std.build.RunStep.create(b, "clone");
        clonestep.addArgs(&.{ "git", "clone", url, repopath });
        result.step.dependOn(&clonestep.step);
    }
};
