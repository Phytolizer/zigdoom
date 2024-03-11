const std = @import("std");

const sources = .{
    "pcsound.c",
    "pcsound_bsd.c",
    "pcsound_sdl.c",
    "pcsound_linux.c",
    "pcsound_win32.c",
};

pub const Package = struct {
    lib: *std.Build.Step.Compile,

    pub fn link(self: Package, exe: *std.Build.Step.Compile) void {
        exe.root_module.addImport("pcsound", &self.lib.root_module);
        exe.linkLibrary(self.lib);
    }
};

pub fn package(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    opts: struct { config_h: *std.Build.Step.ConfigHeader },
) Package {
    const lib = b.addStaticLibrary(.{
        .name = "pcsound",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addIncludePath(.{ .path = this_dir });
    lib.addConfigHeader(opts.config_h);
    lib.installHeadersDirectoryOptions(.{
        .source_dir = .{ .path = this_dir },
        .install_dir = .header,
        .install_subdir = "",
        .include_extensions = &.{".h"},
    });

    inline for (sources) |basepath| {
        const path = this_dir ++ "/" ++ basepath;
        const source_file = std.Build.Module.CSourceFile{ .file = .{ .path = path } };
        lib.addCSourceFile(source_file);
    }

    lib.linkSystemLibrary("SDL2");

    return .{ .lib = lib };
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pkg = package(b, target, optimize);
    b.installArtifact(pkg.lib);
}

const this_dir = struct {
    fn f() []const u8 {
        return comptime std.fs.path.dirname(@src().file) orelse ".";
    }
}.f();
