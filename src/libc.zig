const std = @import("std");
const c = @cImport({
    @cInclude("stdlib.h");
});

// Below is mostly copied from zig/std/heap.zig - it is reimplemented because
// the actual libc used by this program might be different from the one Zig expects.
// This leads to a crash when using Windows UCRT and mixing this allocator
// with plain C code (e.g. M_StringDuplicate -> free)
const CAllocator = struct {
    fn alloc(
        _: *anyopaque,
        len: usize,
        log2_ptr_align: u8,
        ret_addr: usize,
    ) ?[*]u8 {
        _ = ret_addr;
        std.debug.assert(log2_ptr_align <= comptime std.math.log2_int(usize, @alignOf(std.c.max_align_t)));
        // Note that this pointer cannot be aligncasted to max_align_t because if
        // len is < max_align_t then the alignment can be smaller. For example, if
        // max_align_t is 16, but the user requests 8 bytes, there is no built-in
        // type in C that is size 8 and has 16 byte alignment, so the alignment may
        // be 8 bytes rather than 16. Similarly if only 1 byte is requested, malloc
        // is allowed to return a 1-byte aligned pointer.
        return @as(?[*]u8, @ptrCast(c.malloc(len)));
    }

    fn resize(
        _: *anyopaque,
        buf: []u8,
        log2_old_align: u8,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        _ = log2_old_align;
        _ = ret_addr;

        return new_len <= buf.len;
    }

    fn free(
        _: *anyopaque,
        buf: []u8,
        log2_old_align: u8,
        ret_addr: usize,
    ) void {
        _ = log2_old_align;
        _ = ret_addr;
        c.free(buf.ptr);
    }
};

const c_allocator_vtable = std.mem.Allocator.VTable{
    .alloc = CAllocator.alloc,
    .resize = CAllocator.resize,
    .free = CAllocator.free,
};
pub const allocator = std.mem.Allocator{
    .ptr = undefined,
    .vtable = &c_allocator_vtable,
};
