const std = @import("std");
const c = @cImport({
    @cInclude("i_glob.h");
});

const Flags = packed struct(c_int) {
    nocase: bool = false,
    sorted: bool = false,
    _padding: std.meta.Int(.unsigned, @bitSizeOf(c_int) - 2) = 0,
};

comptime {
    // Ensure flags match the C integer representation exactly.
    for (std.meta.fields(Flags)) |field| {
        const name = field.name;
        if (name[0] == '_') continue;
        var name_uc: [name.len]u8 = undefined;
        for (&name_uc, name) |*d, s| d.* = std.ascii.toUpper(s);
        const full_name = "GLOB_FLAG_" ++ name_uc;
        const actual = @field(c, full_name);
        const converted: Flags = @bitCast(actual);
        if (!@field(converted, name)) {
            @compileError(std.fmt.comptimePrint(
                "Flag value mismatch: casting 0x{x:0>2} to " ++ @typeName(Flags) ++ " gave {any}",
                .{ @as(usize, @intCast(actual)), converted },
            ));
        }
    }
}

gpa_state: std.heap.GeneralPurposeAllocator(.{
    .thread_safe = false,
    // .verbose_log = true,
}) = .{},

const Self = @This();

fn allocator(self: *Self) std.mem.Allocator {
    return self.gpa_state.allocator();
}

var g_self = Self{};

const Glob = struct {
    globs: []const []const u8,
    flags: Flags,
    dir: std.fs.Dir.Iterator,
    dirpath: []const u8,
    last_filename: ?[:0]const u8 = null,
    filenames: std.ArrayList([:0]const u8),
    next_index: ?usize = null,

    fn deinit(self: *Glob) void {
        const gpa = g_self.allocator();
        for (self.globs) |g| gpa.free(g);
        gpa.free(self.globs);
        self.dir.dir.close();
        gpa.free(self.dirpath);
        if (self.last_filename) |lfn| gpa.free(lfn);
        for (self.filenames.items) |f| gpa.free(f);
        self.filenames.deinit();
        gpa.destroy(self);
        std.debug.assert(!g_self.gpa_state.detectLeaks());
    }

    fn setLastFilename(self: *Glob, filename: ?[:0]const u8) void {
        if (self.last_filename) |lfn| g_self.allocator().free(lfn);
        self.last_filename = filename;
    }

    fn matchesGlob(name: []const u8, glob: []const u8, flags: Flags) bool {
        var mname = name;
        var mglob = glob;

        const advance = struct {
            fn f(s: []const u8) []const u8 {
                return if (s.len == 0)
                    s
                else
                    s[1..];
            }
        }.f;

        while (mglob.len > 0) {
            var n = if (mname.len == 0) 0 else mname[0];
            var g = if (mglob.len == 0) 0 else mglob[0];
            if (flags.nocase) {
                n = std.ascii.toLower(n);
                g = std.ascii.toLower(g);
            }

            if (g == '*') {
                for (0..mname.len) |i|
                    if (matchesGlob(mname[i..], advance(mglob), flags))
                        return true;

                return mglob.len == 1;
            } else if (g != '?' and n != g) {
                return false;
            }

            mname = advance(mname);
            mglob = advance(mglob);
        }

        return mname.len == 0;
    }

    fn matchesAny(self: *Glob, name: []const u8) bool {
        for (self.globs) |glob| {
            if (matchesGlob(name, glob, self.flags))
                return true;
        }
        return false;
    }

    fn next(self: *Glob) ?[:0]const u8 {
        const gpa = g_self.allocator();

        const entry = blk: while (true) {
            const de = (self.dir.next() catch return null) orelse return null;
            if (de.kind == .directory) continue;
            if (!self.matchesAny(de.name)) continue;
            break :blk de;
        };

        return std.fs.path.joinZ(
            gpa,
            &.{ self.dirpath, entry.name },
        ) catch return null;
    }

    fn readAllFilenames(self: *Glob) !void {
        self.filenames.clearRetainingCapacity();
        self.next_index = 0;

        while (self.next()) |name|
            try self.filenames.append(name);
    }

    fn sortFilenames(self: *Glob) void {
        std.mem.sortUnstable(
            [:0]const u8,
            self.filenames.items,
            self.flags.nocase,
            struct {
                fn lt(nocase: bool, a: [:0]const u8, b: [:0]const u8) bool {
                    return if (nocase)
                        std.ascii.lessThanIgnoreCase(a, b)
                    else
                        std.mem.lessThan(u8, a, b);
                }
            }.lt,
        );
    }
};

fn fallibleStartMultiGlob(directory: []const u8, flags: Flags, globs: []const []const u8, gpa: std.mem.Allocator) !*Glob {
    const result = try gpa.create(Glob);
    result.dirpath = try std.fs.cwd().realpathAlloc(gpa, directory);
    errdefer gpa.free(result.dirpath);
    const dir = try std.fs.cwd().openDir(result.dirpath, .{ .iterate = true });
    errdefer dir.close();
    result.dir = dir.iterate();
    result.globs = globs;
    result.flags = flags;
    result.last_filename = null;
    result.filenames = std.ArrayList([:0]const u8).init(gpa);
    result.next_index = null;
    return result;
}

/// Same as I_StartGlob but multiple glob patterns can be provided. The list
/// of patterns must be terminated with NULL.
export fn I_StartMultiGlob(directory: [*c]const u8, flags: Flags, glob: [*c]const u8, ...) ?*Glob {
    const gpa = g_self.allocator();
    var globs = std.ArrayList([]const u8).init(gpa);
    defer {
        for (globs.items) |g| gpa.free(g);
        globs.deinit();
    }

    const dupeStr = struct {
        fn f(s: [*c]const u8, a: std.mem.Allocator) ![]const u8 {
            return try a.dupe(u8, std.mem.span(s));
        }
    }.f;

    globs.append(dupeStr(glob, gpa) catch return null) catch return null;

    // varargs
    {
        var ap = @cVaStart();
        defer @cVaEnd(&ap);

        while (true) {
            const arg = @cVaArg(&ap, [*c]const u8);
            if (arg == null) break;
            globs.append(dupeStr(arg, gpa) catch return null) catch return null;
        }
    }

    const result = fallibleStartMultiGlob(
        std.mem.span(directory),
        flags,
        globs.toOwnedSlice() catch return null,
        gpa,
    ) catch return null;
    return result;
}

/// Start reading a list of file paths from the given directory which match
/// the given glob pattern. I_EndGlob() must be called on completion.
export fn I_StartGlob(directory: [*c]const u8, glob: [*c]const u8, flags: Flags) ?*Glob {
    return I_StartMultiGlob(
        directory,
        flags,
        glob,
        @as([*c]const u8, null),
    );
}

/// Finish reading file list.
export fn I_EndGlob(glob_in: ?*Glob) void {
    const glob = glob_in orelse return;
    glob.deinit();
}

export fn I_NextGlob(glob_in: ?*Glob) [*c]const u8 {
    const glob = glob_in orelse return null;

    // In unsorted mode we just return the filenames as we read
    // them back from the system API.
    if (!glob.flags.sorted) {
        glob.setLastFilename(glob.next());
        return if (glob.last_filename) |lfn| lfn.ptr else null;
    }

    // In sorted mode we read the whole list of filenames into memory,
    // sort them and return them one at a time.
    const next_index = glob.next_index orelse blk: {
        glob.readAllFilenames() catch return null;
        glob.sortFilenames();
        break :blk 0;
    };
    if (next_index >= glob.filenames.items.len) return null;
    const result = glob.filenames.items[next_index];
    glob.next_index.? += 1;
    return result;
}
