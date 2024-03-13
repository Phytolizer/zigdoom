const std = @import("std");

export fn cext_strcasecmp(s1: [*:0]const u8, s2: [*:0]const u8) c_int {
    if (s1 == s2) return 0;

    const slice1 = std.mem.span(s1);
    const slice2 = std.mem.span(s2);

    const result = std.ascii.orderIgnoreCase(slice1, slice2);
    return switch (result) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}

export fn cext_strncasecmp(s1: [*:0]const u8, s2: [*:0]const u8, n: usize) c_int {
    if (s1 == s2 or n == 0) return 0;

    for (0..n, s1, s2) |_, c1, c2| {
        const l1 = std.ascii.toLower(c1);
        const l2 = std.ascii.toLower(c2);
        if (l1 == 0) {
            return if (l2 == 0)
                0
            else
                -1;
        }
        if (l1 != l2) {
            return if (l1 < l2)
                -1
            else
                1;
        }
    }

    return 0;
}
