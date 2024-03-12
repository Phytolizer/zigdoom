const std = @import("std");

const sources = .{
    "am_map.c",
    "deh_ammo.c",
    "deh_bexstr.c",
    "deh_cheat.c",
    "deh_doom.c",
    "deh_frame.c",
    "deh_misc.c",
    "deh_ptr.c",
    "deh_sound.c",
    "deh_thing.c",
    "deh_weapon.c",
    "d_items.c",
    "d_main.c",
    "d_net.c",
    "dstrings.c",
    "f_finale.c",
    "f_wipe.c",
    "g_game.c",
    "hu_lib.c",
    "hu_stuff.c",
    "info.c",
    "m_menu.c",
    "m_random.c",
    "p_ceilng.c",
    "p_doors.c",
    "p_enemy.c",
    "p_floor.c",
    "p_inter.c",
    "p_lights.c",
    "p_map.c",
    "p_maputl.c",
    "p_mobj.c",
    "p_plats.c",
    "p_pspr.c",
    "p_saveg.c",
    "p_setup.c",
    "p_sight.c",
    "p_spec.c",
    "p_switch.c",
    "p_telept.c",
    "p_tick.c",
    "p_user.c",
    "r_bsp.c",
    "r_data.c",
    "r_draw.c",
    "r_main.c",
    "r_plane.c",
    "r_segs.c",
    "r_sky.c",
    "r_things.c",
    "s_sound.c",
    "sounds.c",
    "statdump.c",
    "st_lib.c",
    "st_stuff.c",
    "wi_stuff.c",
};

pub const Package = struct {
    lib: *std.Build.Step.Compile,

    pub fn link(self: Package, exe: *std.Build.Step.Compile) void {
        exe.root_module.addImport("doom", &self.lib.root_module);
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
        .name = "doom",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .root_source_file = .{ .path = this_dir ++ "/root.zig" },
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

    inline for (sources) |basepath| {
        const path = this_dir ++ "/" ++ basepath;
        const source_file = std.Build.Module.CSourceFile{
            .file = .{ .path = path },
            .flags = &.{"-fno-sanitize=undefined"},
        };
        lib.addCSourceFile(source_file);
    }

    lib.linkSystemLibrary("SDL2");
    lib.linkSystemLibrary("SDL2_mixer");
    lib.linkSystemLibrary("SDL2_net");

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
