const std = @import("std");

const textscreen = @import("textscreen");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const textscreen_pkg = textscreen.package(b, target, optimize);
    b.installArtifact(textscreen_pkg.lib);
}
