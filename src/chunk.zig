const std = @import("std");
const ArrayList = std.ArrayList;

pub const OpCode = enum(u8) { Constant, Add, Subtract, Multiply, Divide, Negate, Return, _ };

const Code = struct {
    // opcode or constant index
    u8,
    // line number
    u64,
};

pub fn init(alloc: std.mem.Allocator) !*Chunk {
    var chunk = try alloc.create(Chunk);

    chunk.code = std.ArrayList(Code).init(alloc);
    chunk.constants = std.ArrayList(f64).init(alloc);

    return chunk;
}

pub const Chunk = struct {
    lines: u64 = 0,
    code: std.ArrayList(Code),
    constants: std.ArrayList(f64),

    fn writeByte(self: *Chunk, byte: u8, line: u64) !void {
        try self.code.append(.{ byte, line });
    }

    pub fn write(self: *Chunk, opcode: OpCode, line: u64) !void {
        try self.code.append(.{ @intFromEnum(opcode), line });
    }

    pub fn writeConstant(self: *Chunk, constant: f64, line: u64) !void {
        try self.write(.Constant, line);
        try self.constants.append(constant);
        try self.writeByte(@intCast(self.constants.items.len - 1), line);
    }
};
