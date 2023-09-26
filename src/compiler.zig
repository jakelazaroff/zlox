const std = @import("std");

const _scanner = @import("./scanner.zig");

pub fn compile(code: []u8) void {
    var scanner = _scanner.init(code);
    var line: u64 = 1;
    while (true) {
        const token = scanner.scanToken();
        if (token.line != line) {
            std.debug.print("{d} ", .{token.line});
            line = token.line;
        } else {
            std.debug.print("   | ", .{});
        }
        std.debug.print("{} {s}\n", .{ token.type, token.code });

        if (token.type == .EOF) break;
    }
}
