const std = @import("std");
const ArrayList = std.ArrayList;

pub fn init(alloc: std.mem.Allocator, code: []u8) !*Scanner {
    var scanner = try alloc.create(Scanner);
    scanner.code = code;
    scanner.start = 0;
    scanner.current = 0;
    scanner.line = 1;

    return scanner;
}

pub const Scanner = struct {
    code: []const u8,
    start: u64 = 0,
    current: u64 = 0,
    line: u64 = 1,

    fn done(self: *Scanner) bool {
        return self.current == self.code.len;
    }

    fn peek(self: *Scanner, lookahead: u8) u8 {
        if (self.current + lookahead >= self.code.len) return 0;
        return self.code[self.current + lookahead];
    }

    fn advance(self: *Scanner) u8 {
        self.current += 1;
        return self.code[self.current - 1];
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (self.done()) return false;
        if (self.code[self.current] != expected) return false;
        self.current += 1;
        return true;
    }

    fn makeToken(self: *Scanner, tokenType: TokenType) Token {
        return Token{
            .type = tokenType,
            .code = self.code[self.start..self.current],
            .line = self.line,
        };
    }

    fn errorToken(self: *Scanner, message: []const u8) Token {
        return Token{
            .type = .Error,
            .code = message,
            .line = self.line,
        };
    }

    fn scanWhitespace(self: *Scanner) void {
        while (true) {
            if (self.done()) return;
            const c = self.peek(0);
            switch (c) {
                ' ', '\r', '\t' => {
                    _ = self.advance();
                },
                '\n' => {
                    self.line += 1;
                    _ = self.advance();
                },
                '/' => {
                    if (self.peek(1) == '/') {
                        while (self.peek(0) != '\n' and !self.done()) _ = self.advance();
                    } else {
                        return;
                    }
                },
                else => {
                    return;
                },
            }
        }
    }

    fn scanString(self: *Scanner) Token {
        while (self.peek(0) != '"' and !self.done()) {
            if (self.peek(0) == '\n') self.line += 1;
            _ = self.advance();
        }

        if (self.done()) {
            return self.errorToken("Unterminated string.");
        }

        // The closing quote.
        _ = self.advance();
        return self.makeToken(.String);
    }

    fn scanNumber(self: *Scanner) Token {
        while (isDigit(self.peek(0))) _ = self.advance();

        if (self.peek(0) == '.' and isDigit(self.peek(1))) {
            // Consume the ".".
            _ = self.advance();

            while (isDigit(self.peek(0))) _ = self.advance();
        }

        return self.makeToken(.Number);
    }

    fn checkKeyword(self: *Scanner, keyword: []const u8, tokenType: TokenType) TokenType {
        if (self.current - self.start != keyword.len) return .Identifier;

        const token = self.code[self.start..self.current];
        if (std.mem.eql(u8, token, keyword)) return tokenType;

        return .Identifier;
    }

    fn identifierType(self: *Scanner) TokenType {
        switch (self.code[self.start]) {
            'a' => {
                return self.checkKeyword("and", .And);
            },
            'c' => {
                return self.checkKeyword("lass", .Class);
            },
            'e' => {
                return self.checkKeyword("else", .Else);
            },
            'f' => {
                if (self.current - self.start > 1) {
                    switch (self.code[self.start + 1]) {
                        'a' => {
                            return self.checkKeyword("false", .False);
                        },
                        'o' => {
                            return self.checkKeyword("for", .For);
                        },
                        'u' => {
                            return self.checkKeyword("fun", .Fun);
                        },
                        else => {
                            return .Identifier;
                        },
                    }
                }
            },
            'i' => {
                return self.checkKeyword("if", .If);
            },
            'n' => {
                return self.checkKeyword("nil", .Nil);
            },
            'o' => {
                return self.checkKeyword("or", .Or);
            },
            'p' => {
                return self.checkKeyword("else", .Print);
            },
            'r' => {
                return self.checkKeyword("else", .Return);
            },
            's' => {
                return self.checkKeyword("else", .Super);
            },
            't' => {
                if (self.current - self.start > 1) {
                    switch (self.code[self.start + 1]) {
                        'h' => {
                            return self.checkKeyword("this", .This);
                        },
                        'r' => {
                            return self.checkKeyword("true", .True);
                        },
                        else => {
                            return .Identifier;
                        },
                    }
                }
            },
            'v' => {
                return self.checkKeyword("else", .Var);
            },
            'w' => {
                return self.checkKeyword("else", .While);
            },
            else => {
                return .Identifier;
            },
        }

        return .Identifier;
    }

    fn scanIdentifier(self: *Scanner) Token {
        while (isAlpha(self.peek(0)) or isDigit(self.peek(0))) _ = self.advance();
        return self.makeToken(self.identifierType());
    }

    pub fn scanToken(self: *Scanner) Token {
        self.scanWhitespace();
        self.start = self.current;
        if (self.done()) return self.makeToken(.EOF);

        const c = self.advance();
        if (isAlpha(c)) return self.scanIdentifier();
        if (isDigit(c)) return self.scanNumber();

        switch (c) {
            '(' => {
                return self.makeToken(.LeftParen);
            },
            ')' => {
                return self.makeToken(.RightParen);
            },
            '{' => {
                return self.makeToken(.LeftBrace);
            },
            '}' => {
                return self.makeToken(.RightBrace);
            },
            ';' => {
                return self.makeToken(.Semicolon);
            },
            ',' => {
                return self.makeToken(.Comma);
            },
            '.' => {
                return self.makeToken(.Dot);
            },
            '-' => {
                return self.makeToken(.Minus);
            },
            '+' => {
                return self.makeToken(.Plus);
            },
            '/' => {
                return self.makeToken(.Slash);
            },
            '*' => {
                return self.makeToken(.Star);
            },
            '!' => {
                return self.makeToken(if (self.match('=')) .BangEqual else .Bang);
            },
            '=' => {
                return self.makeToken(if (self.match('=')) .EqualEqual else .Equal);
            },
            '<' => {
                return self.makeToken(if (self.match('=')) .LessEqual else .Less);
            },
            '>' => {
                return self.makeToken(if (self.match('=')) .GreaterEqual else .Greater);
            },
            '"' => {
                return self.scanString();
            },
            else => {
                return self.errorToken("Unexpected character.");
            },
        }
    }
};

pub const TokenType = enum { // Single-character tokens.
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    Comma,
    Dot,
    Minus,
    Plus,
    Semicolon,
    Slash,
    Star,
    // One or two character tokens.
    Bang,
    BangEqual,
    Equal,
    EqualEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    // Literals.
    Identifier,
    String,
    Number,
    // Keywords.
    And,
    Class,
    Else,
    False,
    For,
    Fun,
    If,
    Nil,
    Or,
    Print,
    Return,
    Super,
    This,
    True,
    Var,
    While,

    Error,
    EOF,
};

pub const Token = struct {
    type: TokenType,
    code: []const u8,
    line: u64,
};

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        c == '_';
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}
