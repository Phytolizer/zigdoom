const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    _ = target; // autofix
    const optimize = b.standardOptimizeOption(.{});
    _ = optimize; // autofix
}
