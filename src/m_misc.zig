const std = @import("std");
const zig = @import("i_system.zig");
const c = @cImport({
    @cInclude("stdlib.h");
});
const libc = @import("libc.zig");

///
/// Safe version of strdup() that checks the string was successfully
/// allocated.
///
pub export fn M_StringDuplicate(orig: [*c]const u8) [*c]u8 {
    const orig_slice = std.mem.span(orig);
    const slice = libc.allocator.dupeZ(u8, orig_slice) catch
        zig.errorFmt("Failed to duplicate string (length {d})", .{orig_slice.len});
    return slice.ptr;
}
