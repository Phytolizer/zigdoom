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

export fn I_ErrorUnformatted(message: [*c]const u8) noreturn {
    while (exit_funcs) |entry| : (exit_funcs = entry.next) {
        if (entry.run_on_error)
            entry.func.?();
    }

    const exit_gui_popup = !c.M_ParmExists("-nogui");

    if (exit_gui_popup and !c.I_ConsoleStdout()) {
        _ = c.SDL_ShowSimpleMessageBox(c.SDL_MESSAGEBOX_ERROR, c.PACKAGE_STRING, message, null);
    }

    c.SDL_Quit();
    _ = gpa_state.deinit();
    std.process.exit(std.math.maxInt(u8));
}
