const std = @import("std");
const ArrayList = std.ArrayList;

pub const OpCode = enum(u8) { Constant, Return, _ };

const Code = struct {
    // opcode or constant index
    u8,
    // line number
    u32,
};

pub fn init(alloc: std.mem.Allocator) Chunk {
    return Chunk{
        .code = std.ArrayList(Code).init(alloc),
        .constants = std.ArrayList(f64).init(alloc),
    };
}

pub const Chunk = struct {
    lines: u32 = 0,
    code: std.ArrayList(Code),
    constants: std.ArrayList(f64),

    fn writeByte(self: *Chunk, byte: u8, line: u32) !void {
        try self.code.append(.{ byte, line });
    }

    pub fn write(self: *Chunk, opcode: OpCode, line: u32) !void {
        try self.code.append(.{ @intFromEnum(opcode), line });
    }

    pub fn writeConstant(self: *Chunk, constant: f64, line: u32) !void {
        try self.write(.Constant, line);
        try self.constants.append(constant);
        try self.writeByte(@intCast(self.constants.items.len - 1), line);
    }

    pub fn disassemble(self: *Chunk, name: []const u8) void {
        std.debug.print("== {s} ==\n", .{name});

        var offset: usize = 0;
        while (offset < self.code.items.len) {
            offset = self.disassembleInstruction(offset);
        }
    }

    fn disassembleInstruction(self: *Chunk, offset: usize) usize {
        const code = self.code.items[offset];

        // print offset
        std.debug.print("{d:0>4} ", .{offset});

        // print line number
        if (offset > 0 and code[1] == self.code.items[offset - 1][1]) {
            std.debug.print("   | ", .{});
        } else {
            std.debug.print("{d: >4} ", .{code[1]});
        }

        const instruction: OpCode = @enumFromInt(code[0]);

        // print instruction
        switch (instruction) {
            .Return => {
                return self.simpleInstruction("OP_RETURN", offset);
            },
            .Constant => {
                return self.constantInstruction("OP_CONSTANT", offset);
            },
            else => {
                std.debug.print("Unknown opcode {}\n", .{instruction});
                return offset + 1;
            },
        }
    }

    fn simpleInstruction(_: *Chunk, name: []const u8, offset: usize) usize {
        std.debug.print("{s}\n", .{name});
        return offset + 1;
    }

    fn constantInstruction(self: *Chunk, name: []const u8, offset: usize) usize {
        const idx = self.code.items[offset + 1][0];
        const value = self.constants.items[idx];
        std.debug.print("{s: <16} {d: >4} '{d}'\n", .{ name, idx, value });
        return offset + 2;
    }
};
