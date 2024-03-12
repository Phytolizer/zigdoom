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
    });
    const install_config_h = b.addInstallFileWithDir(
        .{ .generated = &config_h.output_file },
        .header,
        "config.h",
    );
    b.getInstallStep().dependOn(&install_config_h.step);

    const textscreen_pkg = textscreen.package(b, target, optimize);
    const opl_pkg = opl.package(b, target, optimize, .{ .config_h = config_h });
    const pcsound_pkg = pcsound.package(b, target, optimize, .{ .config_h = config_h });
    const cext_pkg = cext.package(b, target, optimize);
    const src_pkg = src.package(b, target, optimize, .{
        .config_h = config_h,
        .libs = .{
            .textscreen = textscreen_pkg.lib,
            .opl = opl_pkg.lib,
            .pcsound = pcsound_pkg.lib,
        },
        .cext = cext_pkg.lib,
    });
    b.installArtifact(src_pkg.doom);
    b.installArtifact(src_pkg.setup);

    const run = b.addRunArtifact(src_pkg.doom);
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step("run", "Run " ++ package_name);
    run_step.dependOn(&run.step);

    const run_setup = b.addRunArtifact(src_pkg.setup);
    if (b.args) |args| run_setup.addArgs(args);
    const run_setup_step = b.step("run-setup", "Run " ++ package_name ++ " setup");
    run_setup_step.dependOn(&run_setup.step);
}
