const std = @import("std");
const ArrayList = std.ArrayList;

pub const FileLoc = struct {
    line: usize,
    col: usize,
};

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Tag = enum {
        invalid,
        eof,

        comment,

        identifier,
        numberLiteral,
        openParen,
        closeParen,
        openBrace,
        closeBrace,
        semicolon,

        keywordInt,
        keywordVoid,
        keywordReturn,
    };

    pub const Loc = struct {
        start: usize,
        end: usize,
    };
};

pub const TokenList = ArrayList(Token);

pub const LexError = error{
    UnsupportedToken,
    InvalidConstant,
    UnterminatedMultilineComment,
    OutOfMemory,
};

fn isAlpha(c: u8) bool {
    switch (c) {
        'a'...'z', 'A'...'Z' => return true,
        else => return false,
    }
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlphanumeric(c: u8) bool {
    return isAlpha(c) or isDigit(c);
}

pub const Lexer = struct {
    const Self = @This();

    buffer: []const u8,
    index: usize,

    pub fn init(buffer: []const u8) Self {
        const src_start: usize = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0;
        return Lexer{ .buffer = buffer, .index = src_start };
    }

    fn peek(self: *Self) u8 {
        return self.buffer[self.index];
    }

    fn peekAhead(self: *Self, ahead: usize) u8 {
        return self.buffer[self.index + ahead];
    }

    fn getIdentifierTag(ident: []const u8) Token.Tag {
        if (std.mem.eql(u8, ident, "int")) {
            return Token.Tag.keywordInt;
        } else if (std.mem.eql(u8, ident, "void")) {
            return Token.Tag.keywordVoid;
        } else if (std.mem.eql(u8, ident, "return")) {
            return Token.Tag.keywordReturn;
        }

        return Token.Tag.identifier;
    }

    pub fn next(self: *Self) LexError!Token {
        const State = enum {
            Start,

            // Single line comment
            Slash,
            SingleLineComment,

            MultiLineComment,
            MultiLineCommentAsterisk,

            Identifier,
            NumericLiteral,
        };

        var currState = State.Start;
        var start = self.index;
        var end = self.index;

        while (true) {
            if (self.index == self.buffer.len) {
                return Token{ .tag = Token.Tag.eof, .loc = .{ .start = start, .end = end } };
            }

            const c = self.peek();
            switch (currState) {
                .Start => {
                    switch (c) {
                        'a'...'z', 'A'...'Z' => {
                            currState = State.Identifier;
                            start = self.index;
                        },
                        '0'...'9' => {
                            currState = State.NumericLiteral;
                            start = self.index;
                        },
                        '(' => {
                            self.index += 1;
                            return Token{ .tag = Token.Tag.openParen, .loc = .{ .start = start, .end = start + 1 } };
                        },
                        ')' => {
                            self.index += 1;
                            return Token{ .tag = Token.Tag.closeParen, .loc = .{ .start = start, .end = start + 1 } };
                        },
                        '{' => {
                            self.index += 1;
                            return Token{ .tag = Token.Tag.openBrace, .loc = .{ .start = start, .end = start + 1 } };
                        },
                        '}' => {
                            self.index += 1;
                            return Token{ .tag = Token.Tag.closeBrace, .loc = .{ .start = start, .end = start + 1 } };
                        },
                        ';' => {
                            self.index += 1;
                            return Token{ .tag = Token.Tag.semicolon, .loc = .{ .start = start, .end = start + 1 } };
                        },
                        '/' => {
                            self.index += 1;
                            currState = State.Slash;
                        },
                        ' ', '\t', '\n', '\r' => {
                            self.index += 1;
                            start = self.index;
                        },
                        else => {
                            self.index += 1;
                            return Token{ .tag = Token.Tag.invalid, .loc = .{ .start = start, .end = end } };
                        },
                    }
                },
                .Identifier => {
                    switch (c) {
                        'a'...'z', 'A'...'Z', '0'...'9', '_' => {
                            self.index += 1;
                            if (self.index == self.buffer.len) {
                                end = self.index;
                                return Token{ .tag = getIdentifierTag(self.buffer[start..end]), .loc = .{ .start = start, .end = end } };
                            }
                        },
                        else => {
                            end = self.index;
                            return Token{ .tag = getIdentifierTag(self.buffer[start..end]), .loc = .{ .start = start, .end = end } };
                        },
                    }
                },
                .NumericLiteral => {
                    switch (c) {
                        '0'...'9' => {
                            self.index += 1;

                            if (self.index == self.buffer.len) {
                                end = self.index;
                                return Token{ .tag = Token.Tag.numberLiteral, .loc = .{ .start = start, .end = end } };
                            }
                        },
                        'a'...'z', 'A'...'Z', '_', '@' => {
                            return Token{ .tag = Token.Tag.invalid, .loc = .{ .start = start, .end = end } };
                        },
                        else => {
                            end = self.index;
                            return Token{ .tag = Token.Tag.numberLiteral, .loc = .{ .start = start, .end = end } };
                        },
                    }
                },
                .Slash => {
                    switch (c) {
                        '/' => {
                            currState = State.SingleLineComment;
                            self.index += 1;
                        },
                        '*' => {
                            currState = State.MultiLineComment;
                            self.index += 1;
                        },
                        else => {
                            self.index += 1;
                            return Token{ .tag = Token.Tag.invalid, .loc = .{ .start = start, .end = end } };
                        },
                    }
                },
                .SingleLineComment => {
                    switch (c) {
                        '\n' => {
                            currState = State.Start;
                            self.index += 1;
                        },
                        else => {
                            self.index += 1;
                        },
                    }
                },
                .MultiLineComment => {
                    switch (c) {
                        '*' => {
                            currState = State.MultiLineCommentAsterisk;
                            self.index += 1;
                        },
                        else => {
                            self.index += 1;
                        },
                    }
                },
                .MultiLineCommentAsterisk => {
                    switch (c) {
                        '/' => {
                            self.index += 1;
                            currState = State.Start;
                        },
                        else => {
                            self.index += 1;
                            currState = State.MultiLineComment;
                        },
                    }
                },
            }
        }

        return LexError.UnsupportedToken;
    }

    pub fn getErrorLineAndCol(self: *Self, tok: Token) FileLoc {
        var line: usize = 1;
        var col: usize = 1;
        var i: usize = 0;

        while (true) : (i += 1) {
            if (i == tok.loc.start) {
                break;
            }

            if (self.buffer[i] == '\n') {
                line += 1;
                col = 1;
            } else {
                col += 1;
            }
        }

        return FileLoc{ .line = line, .col = col };
    }

    pub fn lexWholeFile(allocator: std.mem.Allocator, data: []const u8) LexError!TokenList {
        var lexer = Lexer.init(data);
        var tokens = TokenList.init(allocator);

        while (true) {
            const token = try lexer.next();
            if (token.tag == Token.Tag.eof) {
                break;
            }

            if (token.tag == Token.Tag.invalid) {
                return LexError.UnsupportedToken;
            }

            const token_copy = Token{ .tag = token.tag, .loc = .{ .start = token.loc.start, .end = token.loc.end } };
            tokens.append(token_copy) catch {
                return LexError.OutOfMemory;
            };
        }

        return tokens;
    }
};

fn tokenEquals(a: Token, b: Token) bool {
    return a.tag == b.tag and a.loc.start == b.loc.start and a.loc.end == b.loc.end;
}

test "expect getErrorLineAndCol to be able to find line and column of a token" {
    const testing = std.testing;

    const program = "int main() { return 0; }";
    const tokens = Lexer.lexWholeFile(std.heap.page_allocator, program) catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        return;
    };

    defer tokens.deinit();

    var lexer = Lexer.init(program);
    const token = tokens.items[5];
    const loc = lexer.getErrorLineAndCol(token);

    try testing.expect(loc.line == 1);
    try testing.expect(loc.col == 14);
}

test "expect lexing empty string to return empty list" {
    const testing = std.testing;

    const tokens = Lexer.lexWholeFile(std.heap.page_allocator, "") catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        return;
    };
    defer tokens.deinit();

    try testing.expect(tokens.items.len == 0);
}

test "expect handling comments correctly" {
    const testing = std.testing;
    const program = "// comment\nidentifier";
    const tokens = Lexer.lexWholeFile(std.heap.page_allocator, program) catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        return;
    };

    defer tokens.deinit();

    try testing.expect(tokens.items.len == 1);
    try testing.expect(tokens.items[tokens.items.len - 1].tag == Token.Tag.identifier);
}
