const std = @import("std");

const _chunk = @import("./chunk.zig");
const Chunk = _chunk.Chunk;
const OpCode = _chunk.OpCode;

pub fn disassemble(chunk: *Chunk, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.code.items.len) {
        offset = disassembleInstruction(chunk, offset);
    }
}

fn disassembleInstruction(chunk: *Chunk, offset: usize) usize {
    const code = chunk.code.items[offset];

    // print offset
    std.debug.print("{d:0>4} ", .{offset});

    // print line number
    if (offset > 0 and code[1] == chunk.code.items[offset - 1][1]) {
        std.debug.print("   | ", .{});
    } else {
        std.debug.print("{d: >4} ", .{code[1]});
    }

    const instruction: OpCode = @enumFromInt(code[0]);

    // print instruction
    switch (instruction) {
        .Return => {
            return simpleInstruction("OP_RETURN", offset);
        },
        .Add => {
            return simpleInstruction("OP_ADD", offset);
        },
        .Subtract => {
            return simpleInstruction("OP_SUBTRACT", offset);
        },
        .Multiply => {
            return simpleInstruction("OP_MULTIPLY", offset);
        },
        .Divide => {
            return simpleInstruction("OP_DIVIDE", offset);
        },
        .Negate => {
            return simpleInstruction("OP_NEGATE", offset);
        },
        .Constant => {
            return constantInstruction(chunk, "OP_CONSTANT", offset);
        },
        else => {
            std.debug.print("Unknown opcode {}\n", .{instruction});
            return offset + 1;
        },
    }
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}

fn constantInstruction(chunk: *Chunk, name: []const u8, offset: usize) usize {
    const idx = chunk.code.items[offset + 1][0];
    const value = chunk.constants.items[idx];
    std.debug.print("{s: <16} {d: >4} '{d}'\n", .{ name, idx, value });
    return offset + 2;
}
