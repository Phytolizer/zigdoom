const std = @import("std");

const doom = @import("doom");
const setup = @import("setup");

const common_sources = [_][]const u8{
    "i_main.c",
    "i_system.c",
    "m_argv.c",
    "m_misc.c",
};

const dedserv_sources = [_][]const u8{
    "d_dedicated.c",
    "d_iwad.c",
    "d_mode.c",
    "deh_str.c",
    "i_timer.c",
    "m_config.c",
    "net_common.c",
    "net_dedicated.c",
    "net_io.c",
    "net_packet.c",
    "net_sdl.c",
    "net_query.c",
    "net_server.c",
    "net_structrw.c",
    "z_native.c",
};

const game_sources = [_][]const u8{
    "aes_prng.c",
    "d_event.c",
    "d_iwad.c",
    "d_loop.c",
    "d_mode.c",
    "deh_str.c",
    "gusconf.c",
    "i_cdmus.c",
    "i_endoom.c",
    "i_flmusic.c",
    "i_input.c",
    "i_joystick.c",
    "i_musicpack.c",
    "i_oplmusic.c",
    "i_pcsound.c",
    "i_sdlmusic.c",
    "i_sdlsound.c",
    "i_sound.c",
    "i_timer.c",
    "i_video.c",
    "i_videohr.c",
    "i_winmusic.c",
    "midifallback.c",
    "midifile.c",
    "mus2mid.c",
    "m_bbox.c",
    "m_cheat.c",
    "m_config.c",
    "m_controls.c",
    "m_fixed.c",
    "net_client.c",
    "net_common.c",
    "net_dedicated.c",
    "net_gui.c",
    "net_io.c",
    "net_loop.c",
    "net_packet.c",
    "net_petname.c",
    "net_query.c",
    "net_sdl.c",
    "net_server.c",
    "net_structrw.c",
    "sha1.c",
    "memio.c",
    "tables.c",
    "v_diskicon.c",
    "v_video.c",
    "w_checksum.c",
    "w_main.c",
    "w_wad.c",
    "w_file.c",
    "w_file_stdc.c",
    "w_file_posix.c",
    "w_file_win32.c",
    "w_merge.c",
    "z_zone.c",
};

const dehacked_sources = [_][]const u8{
    "deh_io.c",
    "deh_main.c",
    "deh_mapping.c",
    "deh_text.c",
};

const setup_sources = [_][]const u8{
    "deh_str.c",
    "d_mode.c",
    "d_iwad.c",
    "i_timer.c",
    "m_config.c",
    "m_controls.c",
    "net_io.c",
    "net_packet.c",
    "net_petname.c",
    "net_sdl.c",
    "net_query.c",
    "net_structrw.c",
    "z_native.c",
};

const slash = std.fs.path.sep_str;

const sources = common_sources ++ game_sources ++ dehacked_sources;
const all_setup_sources = common_sources ++ setup_sources;

pub const Package = struct {
    doom: *std.Build.Step.Compile,
    setup: *std.Build.Step.Compile,
};

fn linkWindows(exe: *std.Build.Step.Compile) void {
    exe.subsystem = .Windows;
    inline for (.{
        "Advapi32",
        "Gdi32",
        "Imm32",
        "Iphlpapi",
        "Ole32",
        "OleAut32",
        "SetupAPI",
        "Shell32",
        "User32",
        "Version",
        "Winmm",
        "Ws2_32",
    }) |libname| {
        exe.linkSystemLibrary(libname);
    }
}

pub fn package(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    opts: struct {
        config_h: *std.Build.Step.ConfigHeader,
        libs: struct {
            textscreen: *std.Build.Step.Compile,
            opl: *std.Build.Step.Compile,
            pcsound: *std.Build.Step.Compile,
        },
        cext: *std.Build.Step.Compile,
    },
) Package {
    const doom_lib = b.addStaticLibrary(.{
        .name = "zigdoom",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .root_source_file = .{ .path = this_dir ++ "/root.zig" },
    });
    doom_lib.addIncludePath(.{ .path = this_dir });
    doom_lib.addConfigHeader(opts.config_h);
    doom_lib.linkLibrary(opts.libs.textscreen);
    doom_lib.linkLibrary(opts.libs.opl);
    doom_lib.linkLibrary(opts.libs.pcsound);
    const doom_exe = b.addExecutable(.{
        .name = "chocolate-doom",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    if (target.result.os.tag == .windows)
        linkWindows(doom_exe);
    doom_exe.linkLibrary(doom_lib);
    doom_exe.addIncludePath(.{ .path = this_dir });
    doom_exe.addConfigHeader(opts.config_h);
    doom_exe.linkLibrary(opts.libs.textscreen);
    doom_exe.linkLibrary(opts.libs.opl);
    doom_exe.linkLibrary(opts.libs.pcsound);
    const doom_pkg = doom.package(b, target, optimize, .{
        .config_h = opts.config_h,
        .libs = &.{opts.cext},
    });
    doom_exe.linkLibrary(doom_pkg.lib);

    doom_exe.addCSourceFiles(.{
        .root = .{ .path = this_dir },
        .files = &sources,
        .flags = &.{"-fno-sanitize=undefined"},
    });

    doom_exe.linkSystemLibrary("SDL2");
    doom_exe.linkSystemLibrary("SDL2_net");
    doom_exe.linkSystemLibrary("SDL2_mixer");
    doom_exe.linkSystemLibrary("fluidsynth");
    doom_exe.linkSystemLibrary("samplerate");
    doom_exe.linkSystemLibrary("libpng");
    if (target.result.os.tag == .windows)
        doom_exe.linkSystemLibrary("SDL2main");

    const setup_exe = b.addExecutable(.{
        .name = "chocolate-setup",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    if (target.result.os.tag == .windows)
        linkWindows(setup_exe);
    setup_exe.addIncludePath(.{ .path = this_dir });
    setup_exe.addConfigHeader(opts.config_h);
    setup_exe.addCSourceFiles(.{
        .root = .{ .path = this_dir },
        .files = &all_setup_sources,
        .flags = &.{"-fno-sanitize=undefined"},
    });

    setup_exe.linkSystemLibrary("SDL2");
    setup_exe.linkSystemLibrary("SDL2_mixer");
    setup_exe.linkSystemLibrary("SDL2_net");
    const setup_pkg = setup.package(b, target, optimize, .{
        .config_h = opts.config_h,
        .libs = &.{opts.cext},
    });
    setup_exe.linkLibrary(doom_lib);
    setup_exe.linkLibrary(setup_pkg.lib);
    setup_exe.linkLibrary(opts.libs.textscreen);
    if (target.result.os.tag == .windows)
        setup_exe.linkSystemLibrary("SDL2main");

    return .{ .doom = doom_exe, .setup = setup_exe };
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pkg = package(b, target, optimize);
    b.installArtifact(pkg);
}

const this_dir = struct {
    fn f() []const u8 {
        return comptime std.fs.path.dirname(@src().file) orelse ".";
    }
}.f();

const root_path = std.fs.path.diskDesignator(this_dir) ++ slash;
