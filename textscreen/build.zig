const std = @import("std");

const sources = [_][]const u8{
    "txt_conditional.c",
    "txt_checkbox.c",
    "txt_desktop.c",
    "txt_dropdown.c",
    "txt_fileselect.c",
    "txt_gui.c",
    "txt_inputbox.c",
    "txt_io.c",
    "txt_button.c",
    "txt_label.c",
    "txt_radiobutton.c",
    "txt_scrollpane.c",
    "txt_separator.c",
    "txt_spinctrl.c",
    "txt_sdl.c",
    "txt_strut.c",
    "txt_table.c",
    "txt_utf8.c",
    "txt_widget.c",
    "txt_window.c",
    "txt_window_action.c",
};

pub const Package = struct {
    lib: *std.Build.Step.Compile,

    pub fn link(self: Package, exe: *std.Build.Step.Compile) void {
        exe.root_module.addImport("textscreen", &self.lib.root_module);
        exe.linkLibrary(self.lib);
    }
};

pub fn package(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) Package {
    const lib = b.addStaticLibrary(.{
        .name = "textscreen",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addIncludePath(.{ .path = this_dir });
    lib.addIncludePath(.{ .path = this_dir ++ "/../src" });

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
