const std = @import("std");
const c = @cImport({
    @cInclude("config.h");
    @cInclude("stdio.h");
    @cInclude("i_system.h");
    @cInclude("m_argv.h");
    @cInclude("m_misc.h");
    @cInclude("SDL.h");
});

const AtExitFunc = ?*const fn () callconv(.C) void;
comptime {
    std.debug.assert(AtExitFunc == c.atexit_func_t);
}

const AtExitListEntry = struct {
    func: c.atexit_func_t,
    run_on_error: bool,
    next: ?*AtExitListEntry = null,
};

var exit_funcs: ?*AtExitListEntry = null;

var gpa_state = std.heap.GeneralPurposeAllocator(.{ .thread_safe = false, .safety = false }){};

fn gpa() std.mem.Allocator {
    return gpa_state.allocator();
}

export fn I_AtExit(func: AtExitFunc, run_on_error: bool) void {
    const entry = gpa().create(AtExitListEntry) catch unreachable;
    entry.* = .{
        .func = func,
        .run_on_error = run_on_error,
        .next = exit_funcs,
    };
    exit_funcs = entry;
}

export fn I_Quit() noreturn {
    while (exit_funcs) |entry| : (exit_funcs = entry.next) {
        entry.func.?();
    }
    c.SDL_Quit();
    _ = gpa_state.deinit();
    std.process.exit(0);
}

fn ReturnType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .Pointer => |p| return ReturnType(p.child),
        .Fn => |f| return f.return_type.?,
        else => @compileLog(T),
    };
}

fn dispatchVa7(
    f: anytype,
    const_args: anytype,
    args: []const [*c]const u8,
) ReturnType(@TypeOf(f)) {
    // HACK: dispatch on count to avoid vararg issues - it is known to be <= 7
    return switch (args.len) {
        1 => @call(.auto, f, const_args ++ .{args[0]}),
        2 => @call(.auto, f, const_args ++ .{ args[0], args[1] }),
        3 => @call(.auto, f, const_args ++ .{ args[0], args[1], args[2] }),
        4 => @call(.auto, f, const_args ++ .{ args[0], args[1], args[2], args[3] }),
        5 => @call(.auto, f, const_args ++ .{ args[0], args[1], args[2], args[3], args[4] }),
        6 => @call(.auto, f, const_args ++ .{ args[0], args[1], args[2], args[3], args[4], args[5] }),
        7 => @call(.auto, f, const_args ++ .{ args[0], args[1], args[2], args[3], args[4], args[5], args[6] }),
        else => {
            std.log.err("dispatchVa7: too many arguments ({d})", .{args.len});
            std.process.abort();
        },
    };
}

export fn I_ErrorUnformatted(message: [*c]const u8) noreturn {
    while (exit_funcs) |entry| : (exit_funcs = entry.next) {
        if (entry.run_on_error)
            entry.func.?();
    }

    const exit_gui_popup = c.M_ParmExists("-nogui") == 0;

    if (exit_gui_popup and c.I_ConsoleStdout() == 0) {
        _ = c.SDL_ShowSimpleMessageBox(c.SDL_MESSAGEBOX_ERROR, c.PACKAGE_STRING, message, null);
    }

    c.SDL_Quit();
    _ = gpa_state.deinit();
    std.process.exit(std.math.maxInt(u8));
}
