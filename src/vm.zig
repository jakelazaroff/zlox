const std = @import("std");
const alloc = std.heap.page_allocator;
const ArrayList = std.ArrayList;

const _chunk = @import("./chunk.zig");
const Chunk = _chunk.Chunk;

const _compiler = @import("./compiler.zig");

pub const InterpreterError = error{ CompileError, RuntimeError };

pub fn init() VM {
    return VM{
        .chunk = undefined,
        .stack = std.ArrayList(f64).init(alloc),
    };
}

pub const VM = struct {
    chunk: *Chunk,
    ip: usize = 0,
    stack: ArrayList(f64),

    pub fn interpret(self: *VM, source: []u8) !void {
        self.chunk = try _chunk.init(alloc);
        defer alloc.destroy(self.chunk);

        var compiler = _compiler.init();
        try compiler.compile(source, self.chunk);
        self.ip = 0;
        try self.run();
    }

    fn readByte(self: *VM) u8 {
        const code = self.chunk.code.items[self.ip];
        self.ip += 1;

        return code[0];
    }

    fn binaryOp(self: *VM, op: Operation) !void {
        const b = self.stack.pop();
        const a = self.stack.pop();
        try self.stack.append(op(a, b));
    }

    fn run(self: *VM) !void {
        while (true) {
            const code = self.readByte();
            const instruction: _chunk.OpCode = @enumFromInt(code);
            switch (instruction) {
                .Constant => {
                    const value = self.chunk.constants.items[self.readByte()];
                    try self.stack.append(value);
                },
                .Add => {
                    try self.binaryOp(add);
                },
                .Subtract => {
                    try self.binaryOp(sub);
                },
                .Multiply => {
                    try self.binaryOp(mul);
                },
                .Divide => {
                    try self.binaryOp(div);
                },
                .Negate => {
                    try self.stack.append(-self.stack.pop());
                },
                .Return => {
                    const value = self.stack.pop();
                    std.debug.print("{d}\n", .{value});
                    return;
                },
                else => {
                    return InterpreterError.RuntimeError;
                },
            }
        }
    }
};

const Operation = *const fn (a: f64, b: f64) f64;

fn add(a: f64, b: f64) f64 {
    return a + b;
}

fn sub(a: f64, b: f64) f64 {
    return a - b;
}

fn mul(a: f64, b: f64) f64 {
    return a * b;
}

fn div(a: f64, b: f64) f64 {
    return a / b;
}
