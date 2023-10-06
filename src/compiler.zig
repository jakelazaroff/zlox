const std = @import("std");
const alloc = std.heap.page_allocator;

const _chunk = @import("./chunk.zig");
const debug = @import("./debug.zig");
const _scanner = @import("./scanner.zig");
const Token = @import("./scanner.zig").Token;
const TokenType = @import("./scanner.zig").TokenType;
const InterpreterError = @import("./vm.zig").InterpreterError;
const _value = @import("./value.zig");

const Precedence = enum(u8) {
    None,
    Assignment, // =
    Or, // or
    And, // and
    Equality, // == !==
    Comparison, // < > <= >=
    Term, // + -
    Factor, // * /
    Unary, // ! -
    Call, // . ()
    Primary,
};

const ParseFn = *const fn (*Parser) anyerror!void;

const ParseRule = struct {
    prefix: ?ParseFn,
    infix: ?ParseFn,
    precedence: Precedence,
};

pub fn init() Parser {
    return Parser{ .chunk = undefined, .scanner = undefined };
}

pub const Parser = struct {
    chunk: *_chunk.Chunk,
    scanner: *_scanner.Scanner,
    current: ?Token = undefined,
    previous: ?Token = undefined,
    hadError: bool = false,
    panicMode: bool = false,

    pub fn compile(self: *Parser, code: []u8, chunk: *_chunk.Chunk) !void {
        self.chunk = chunk;
        self.scanner = try _scanner.init(alloc, code);
        self.advance();
        try self.expression();
        self.consume(.EOF, "Expect end of expression.");
        try self.emit(.Return);

        if (!self.hadError) {
            debug.disassemble(self.chunk, "code");
        }
    }

    fn advance(self: *Parser) void {
        self.previous = self.current;

        while (true) {
            const current = self.scanner.scanToken();
            self.current = current;
            if (current.type != .Error) break;

            self.errorAtCurrent(current.code);
        }
    }

    fn expression(self: *Parser) !void {
        try self.parsePrecedence(.Assignment);
    }

    fn grouping(self: *Parser) !void {
        try self.expression();
        self.consume(.RightParen, "Expect ')' after expression.");
    }

    fn unary(self: *Parser) !void {
        const previous = self.previous.?;

        // Compile the operand.
        try self.parsePrecedence(.Unary);

        // Emit the operator instruction.
        switch (previous.type) {
            .Bang => {
                try self.emit(.Not);
            },
            .Minus => {
                try self.emit(.Negate);
            },
            else => {
                unreachable;
            },
        }
    }

    fn binary(self: *Parser) !void {
        const previous = self.previous.?;
        const rule = rules.get(previous.type).?;

        try self.parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

        switch (previous.type) {
            .BangEqual => {
                try self.emit(.Equal);
                try self.emit(.Not);
            },
            .EqualEqual => {
                try self.emit(.Equal);
            },
            .Greater => {
                try self.emit(.Greater);
            },
            .GreaterEqual => {
                try self.emit(.Less);
                try self.emit(.Not);
            },
            .Less => {
                try self.emit(.Less);
            },
            .LessEqual => {
                try self.emit(.Greater);
                try self.emit(.Not);
            },
            .Plus => {
                try self.emit(.Add);
            },
            .Minus => {
                try self.emit(.Subtract);
            },
            .Star => {
                try self.emit(.Multiply);
            },
            .Slash => {
                try self.emit(.Divide);
            },
            else => {
                unreachable;
            },
        }
    }

    fn literal(self: *Parser) !void {
        const previous = self.previous.?;
        switch (previous.type) {
            .False => {
                try self.emit(.False);
            },
            .Nil => {
                try self.emit(.Nil);
            },
            .True => {
                try self.emit(.True);
            },
            else => {
                unreachable;
            },
        }
    }

    fn parsePrecedence(self: *Parser, precedence: Precedence) !void {
        self.advance();

        const previous = self.previous.?;
        const rule = rules.get(previous.type).?;
        if (rule.prefix) |prefixFn| {
            try prefixFn(self);
        } else {
            self.err("Expect expression.");
            return;
        }

        while (@intFromEnum(precedence) <= @intFromEnum(rules.get(self.current.?.type).?.precedence)) {
            self.advance();
            const infix = rules.get(self.previous.?.type).?.infix;
            if (infix) |infixFn| {
                try infixFn(self);
            }
        }
    }

    fn number(self: *Parser) !void {
        const value = try std.fmt.parseFloat(f64, self.previous.?.code);
        try self.emitConstant(_value.numberVal(value));
    }

    fn consume(self: *Parser, tokenType: TokenType, message: []const u8) void {
        const current = self.current.?;
        if (current.type == tokenType) {
            self.advance();
            return;
        }

        self.errorAtCurrent(message);
    }

    fn emit(self: *Parser, opcode: _chunk.OpCode) !void {
        if (self.previous) |previous| {
            return self.chunk.write(opcode, previous.line);
        }
    }

    fn emitConstant(self: *Parser, constant: _value.Value) !void {
        return self.chunk.writeConstant(constant, self.previous.?.line);
    }

    fn errorAtCurrent(self: *Parser, message: []const u8) void {
        self.errorAt(self.current.?, message);
    }

    fn errorAt(self: *Parser, token: Token, message: []const u8) void {
        if (self.panicMode) return;
        self.panicMode = true;

        std.debug.print("[line {d}] Error", .{token.line});

        if (token.type == .EOF) {
            std.debug.print(" at end", .{});
        } else if (token.type == .Error) {
            // Nothing.
        } else {
            std.debug.print(" at {s}", .{token.code});
        }

        std.debug.print(": {s}\n", .{message});
        self.hadError = true;
    }

    fn err(self: *Parser, message: []const u8) void {
        self.errorAt(self.previous.?, message);
    }

    const rules = std.EnumMap(TokenType, ParseRule).init(.{
        .LeftParen = ParseRule{ .prefix = grouping, .infix = undefined, .precedence = .None },
        .RightParen = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .LeftBrace = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .RightBrace = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Comma = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Dot = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Minus = ParseRule{ .prefix = unary, .infix = binary, .precedence = .Term },
        .Plus = ParseRule{ .prefix = undefined, .infix = binary, .precedence = .Term },
        .Semicolon = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Slash = ParseRule{ .prefix = undefined, .infix = binary, .precedence = .Factor },
        .Star = ParseRule{ .prefix = undefined, .infix = binary, .precedence = .Factor },
        .Bang = ParseRule{ .prefix = unary, .infix = undefined, .precedence = .None },
        .BangEqual = ParseRule{ .prefix = undefined, .infix = binary, .precedence = .Equality },
        .Equal = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .EqualEqual = ParseRule{ .prefix = undefined, .infix = binary, .precedence = .Equality },
        .Greater = ParseRule{ .prefix = undefined, .infix = binary, .precedence = .Comparison },
        .GreaterEqual = ParseRule{ .prefix = undefined, .infix = binary, .precedence = .Comparison },
        .Less = ParseRule{ .prefix = undefined, .infix = binary, .precedence = .Comparison },
        .LessEqual = ParseRule{ .prefix = undefined, .infix = binary, .precedence = .Comparison },
        .Identifier = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .String = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Number = ParseRule{ .prefix = number, .infix = undefined, .precedence = .None },
        .And = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Class = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Else = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .False = ParseRule{ .prefix = literal, .infix = undefined, .precedence = .None },
        .For = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Fun = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .If = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Nil = ParseRule{ .prefix = literal, .infix = undefined, .precedence = .None },
        .Or = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Print = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Return = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Super = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .This = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .True = ParseRule{ .prefix = literal, .infix = undefined, .precedence = .None },
        .Var = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .While = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .Error = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
        .EOF = ParseRule{ .prefix = undefined, .infix = undefined, .precedence = .None },
    });
};
