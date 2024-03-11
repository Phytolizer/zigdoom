const std = @import("std");

const cext = @import("cext");
const textscreen = @import("textscreen");
const opl = @import("opl");
const pcsound = @import("pcsound");
const src = @import("src");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const package_name = "Chocolate Doom";
    const package_tarname = "zigdoom";
    const package_version = "0.0.0";
    const package_string = package_name ++ " " ++ package_version;
    const program_prefix = comptime blk: {
        const shortname = package_name[0..std.mem.lastIndexOf(u8, package_name, " Doom").?];
        var result: [shortname.len]u8 = undefined;
        for (&result, shortname) |*r, c| r.* = std.ascii.toLower(c);
        break :blk result ++ "-";
    };

    const config_h = b.addConfigHeader(.{
        .style = .{ .cmake = .{ .path = "cmake/config.h.cin" } },
        .include_path = "config.h",
    }, .{
        .PACKAGE_NAME = package_name,
        .PACKAGE_TARNAME = package_tarname,
        .PACKAGE_VERSION = package_version,
        .PACKAGE_STRING = package_string,
        .PROGRAM_PREFIX = program_prefix,
        .HAVE_FLUIDSYNTH = true,
        .HAVE_LIBSAMPLERATE = true,
        .HAVE_LIBPNG = true,
        .HAVE_DIRENT_H = true,
    });

    const textscreen_pkg = textscreen.package(b, target, optimize);
    b.installArtifact(textscreen_pkg.lib);
    const opl_pkg = opl.package(b, target, optimize, .{ .config_h = config_h });
    b.installArtifact(opl_pkg.lib);
    const pcsound_pkg = pcsound.package(b, target, optimize, .{ .config_h = config_h });
    b.installArtifact(pcsound_pkg.lib);
    const cext_pkg = cext.package(b, target, optimize);
    b.installArtifact(cext_pkg.lib);
    const exe = src.package(b, target, optimize, .{
        .config_h = config_h,
        .libs = &.{ textscreen_pkg.lib, opl_pkg.lib, pcsound_pkg.lib },
        .doom_libs = &.{cext_pkg.lib},
    });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step("run", "Run " ++ package_name);
    run_step.dependOn(&run.step);
}
