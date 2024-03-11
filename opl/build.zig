const std = @import("std");
const Sdk = @import("sdl2");

const sources = [_][]const u8{
    "opl.c",
    "opl_linux.c",
    "opl_obsd.c",
    "opl_queue.c",
    "opl_sdl.c",
    "opl_timer.c",
    "opl_win32.c",
    "ioperm_sys.c",
    "opl3.c",
};

pub const Package = struct {
    lib: *std.Build.Step.Compile,

    pub fn link(self: Package, exe: *std.Build.Step.Compile) void {
        exe.root_module.addImport("opl", &self.lib.root_module);
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
        .name = "opl",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addIncludePath(.{ .path = this_dir });
    lib.addIncludePath(.{ .path = this_dir ++ "/../src" });
    lib.addConfigHeader(opts.config_h);

    inline for (sources) |basepath| {
        const path = this_dir ++ "/" ++ basepath;
        const source_file = std.Build.Module.CSourceFile{ .file = .{ .path = path } };
        lib.addCSourceFile(source_file);
    }

    const sdl = Sdk.init(b, null);
    sdl.link(lib, .dynamic);
    lib.linkSystemLibrary("SDL2_mixer");

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
