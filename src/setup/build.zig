const std = @import("std");

const sources = .{
    "compatibility.c",
    "display.c",
    "joystick.c",
    "keyboard.c",
    "mainmenu.c",
    "mode.c",
    "mouse.c",
    "multiplayer.c",
    "sound.c",
    "execute.c",
    "txt_joyaxis.c",
    "txt_joybinput.c",
    "txt_keyinput.c",
    "txt_mouseinput.c",
};

pub const Package = struct {
    lib: *std.Build.Step.Compile,

    pub fn link(self: Package, exe: *std.Build.Step.Compile) void {
        exe.root_module.addImport("setup", &self.lib.root_module);
        exe.linkLibrary(self.lib);
    }
};

pub fn package(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    opts: struct {
        config_h: *std.Build.Step.ConfigHeader,
        libs: []const *std.Build.Step.Compile,
    },
) Package {
    const lib = b.addStaticLibrary(.{
        .name = "setup",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addIncludePath(.{ .path = this_dir });
    lib.addIncludePath(.{ .path = this_dir ++ "/.." });
    lib.addConfigHeader(opts.config_h);
    for (opts.libs) |l| lib.linkLibrary(l);
    lib.installHeadersDirectoryOptions(.{
        .source_dir = .{ .path = this_dir },
        .install_dir = .header,
        .install_subdir = "",
        .include_extensions = &.{".h"},
    });

    lib.addCSourceFiles(.{
        .root = .{ .path = this_dir },
        .flags = &.{"-fno-sanitize=undefined"},
        .files = &sources,
    });

    lib.linkSystemLibrary("SDL2");
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
