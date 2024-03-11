const std = @import("std");

const doom = @import("doom");

const common_sources = .{
    "i_main.c",
    "i_system.c",
    "m_argv.c",
    "m_misc.c",
};

const dedserv_sources = .{
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

const game_sources = .{
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
    "i_glob.c",
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

const dehacked_sources = .{
    "deh_io.c",
    "deh_main.c",
    "deh_mapping.c",
    "deh_text.c",
};

const sources = common_sources ++ game_sources ++ dehacked_sources;

pub fn package(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    opts: struct {
        config_h: *std.Build.Step.ConfigHeader,
        libs: []const *std.Build.Step.Compile,
    },
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "chocolate-doom",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe.addIncludePath(.{ .path = this_dir });
    exe.addConfigHeader(opts.config_h);
    for (opts.libs) |l| {
        exe.linkLibrary(l);
    }
    const doom_pkg = doom.package(b, target, optimize, .{ .config_h = opts.config_h });
    exe.linkLibrary(doom_pkg.lib);

    inline for (sources) |basepath| {
        const path = this_dir ++ "/" ++ basepath;
        const source_file = std.Build.Module.CSourceFile{ .file = .{ .path = path } };
        exe.addCSourceFile(source_file);
    }

    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2_net");
    exe.linkSystemLibrary("SDL2_mixer");
    exe.linkSystemLibrary("fluidsynth");
    exe.linkSystemLibrary("png");

    return exe;
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
