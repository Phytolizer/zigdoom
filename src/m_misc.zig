const std = @import("std");
const zig = @import("i_system.zig");
const c = @cImport({
    @cInclude("stdlib.h");
});

///
/// Safe version of strdup() that checks the string was successfully
/// allocated.
///
pub export fn M_StringDuplicate(orig: [*c]const u8) [*c]u8 {
    const orig_slice = std.mem.span(orig);
    const result = @as([*]u8, @ptrCast(c.malloc(orig_slice.len + 1) orelse {
        zig.errorFmt("Failed to duplicate string (length {d})", .{orig_slice.len});
    }));
    @memcpy(result, orig_slice);
    result[orig_slice.len] = 0;
    return result;
}
