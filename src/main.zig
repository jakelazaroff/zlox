const std = @import("std");
const alloc = std.heap.page_allocator;

const _chunk = @import("chunk.zig");
const _vm = @import("vm.zig");

pub fn main() !void {
    var chunk = _chunk.init(alloc);
    var vm = _vm.init(alloc, &chunk);

    try chunk.writeConstant(1.2, 123);
    try chunk.writeConstant(3.4, 123);
    try chunk.write(.Add, 123);
    try chunk.writeConstant(5.6, 123);
    try chunk.write(.Divide, 123);

    try chunk.write(.Negate, 123);
    try chunk.write(.Return, 123);

    chunk.disassemble("test chunk");
    try vm.interpret();
}
