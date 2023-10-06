const std = @import("std");
const alloc = std.heap.page_allocator;
const ArrayList = std.ArrayList;

const _chunk = @import("./chunk.zig");
const Chunk = _chunk.Chunk;

const _value = @import("./value.zig");
const Value = _value.Value;

const _compiler = @import("./compiler.zig");

pub const InterpreterError = error{ CompileError, RuntimeError };

pub fn init() VM {
    return VM{
        .chunk = undefined,
        .stack = std.ArrayList(Value).init(alloc),
    };
}

pub const VM = struct {
    chunk: *Chunk,
    ip: usize = 0,
    stack: ArrayList(Value),

    fn resetStack(self: *VM) void {
        self.stack.clearAndFree();
        self.stack = std.ArrayList(Value).init(alloc);
    }

    fn runtimeError(self: *VM, format: []const u8) void {
        _ = format;
        //   va_list args;
        //   va_start(args, format);
        //   vfprintf(stderr, format, args);
        //   va_end(args);
        //   fputs("\n", stderr);

        //   size_t instruction = vm.ip - vm.chunk->code - 1;
        //   int line = vm.chunk->lines[instruction];
        //   fprintf(stderr, "[line %d] in script\n", line);
        self.resetStack();
    }

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

    fn binaryOp(self: *VM, comptime T: type, comptime op: fn (a: f64, b: f64) T) !void {
        if (!_value.isNumber(self.peek(0)) or !_value.isNumber(self.peek(1))) {
            self.runtimeError("Operands must be numbers,");
            return InterpreterError.RuntimeError;
        }

        const b = self.stack.pop().Number;
        const a = self.stack.pop().Number;

        switch (T) {
            bool => {
                try self.stack.append(Value{ .Bool = op(a, b) });
            },
            f64 => {
                try self.stack.append(Value{ .Number = op(a, b) });
            },
            else => {
                @compileError("T must be a bool or an f64");
            },
        }
    }

    fn peek(self: *VM, lookahead: u8) Value {
        return self.stack.items[self.stack.items.len - lookahead - 1];
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
                .Nil => {
                    try self.stack.append(_value.nilVal());
                },
                .True => {
                    try self.stack.append(_value.boolVal(true));
                },
                .False => {
                    try self.stack.append(_value.boolVal(false));
                },
                .Equal => {
                    const a = self.stack.pop();
                    const b = self.stack.pop();
                    try self.stack.append(_value.boolVal(_value.valuesEqual(a, b)));
                },
                .Greater => {
                    try self.binaryOp(bool, gt);
                },
                .Less => {
                    try self.binaryOp(bool, lt);
                },
                .Add => {
                    try self.binaryOp(f64, add);
                },
                .Subtract => {
                    try self.binaryOp(f64, sub);
                },
                .Multiply => {
                    try self.binaryOp(f64, mul);
                },
                .Divide => {
                    try self.binaryOp(f64, div);
                },
                .Not => {
                    try self.stack.append(_value.boolVal(isFalsy(self.stack.pop())));
                },
                .Negate => {
                    if (@as(_value.ValueType, self.peek(0)) != _value.ValueType.Number) {
                        self.runtimeError("Operand must be a number.");
                        return InterpreterError.RuntimeError;
                    }

                    try self.stack.append(Value{ .Number = -self.stack.pop().Number });
                },
                .Return => {
                    const value = self.stack.pop();
                    _value.printValue(value);
                    return;
                },
                else => {
                    return InterpreterError.RuntimeError;
                },
            }
        }
    }
};

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

fn gt(a: f64, b: f64) bool {
    return a > b;
}

fn lt(a: f64, b: f64) bool {
    return a < b;
}

fn isFalsy(value: Value) bool {
    return _value.isNil(value) or (_value.isBool(value) and !value.Bool);
}
