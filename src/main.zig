const std = @import("std");
const alloc = std.heap.page_allocator;

const chunk = @import("chunk.zig");

pub fn main() !void {
    var c = chunk.init(alloc);

    try c.writeConstant(1.2, 123);
    try c.write(.Return, 123);

    c.disassemble("test chunk");
}
