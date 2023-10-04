const std = @import("std");
const alloc = std.heap.page_allocator;

const _chunk = @import("chunk.zig");
const _vm = @import("vm.zig");

pub fn main() !void {
    const args = try std.process.argsAlloc(alloc);
    var vm = _vm.init();
    // defer alloc.destroy(&vm);

    switch (args.len) {
        1 => {
            try repl(&vm);
        },
        2 => {
            std.debug.print("file", .{});
        },
        else => {
            std.debug.print("Usage: zlox [path]", .{});
            std.process.exit(64);
        },
    }
}

fn repl(vm: *_vm.VM) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    while (true) {
        try stdout.print("> ", .{});

        try stdin.streamUntilDelimiter(writer, '\n', null);
        const pos = try stream.getPos();

        if (pos == 0) {
            try stdout.print("\n", .{});
            break;
        }

        std.debug.print("{s}\n", .{buf[0..pos]});
        try vm.interpret(buf[0..pos]);
        try stream.seekTo(0);
    }
}
