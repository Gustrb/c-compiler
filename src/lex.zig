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

    /// For debugging purposes
    pub fn dump(self: *Self, token: *const Token) void {
        std.debug.print("{s} \"{s}\"\n", .{ @tagName(token.tag), self.buffer[token.loc.start..token.loc.end] });
    }

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

    // TODO: Rewrite this to be a proper state machine
    pub fn next(self: *Self) LexError!Token {
        while (self.index < self.buffer.len and std.ascii.isWhitespace(self.buffer[self.index])) {
            self.index += 1;
        }

        var token: Token = .{
            .tag = undefined,
            .loc = .{ .start = self.index, .end = undefined },
        };

        if (self.index + 1 < self.buffer.len and self.peek() == '/' and self.peekAhead(1) == '/') {
            token.tag = .comment;
            while (self.index < self.buffer.len and self.peek() != '\n') {
                self.index += 1;
            }

            token.loc.end = self.index;
            return token;
        }

        if (self.index + 1 < self.buffer.len and self.peek() == '/' and self.peekAhead(1) == '*') {
            token.tag = .comment;
            while (self.index < self.buffer.len) {
                if (self.peek() == '*' and self.peekAhead(1) == '/') {
                    self.index += 2;
                    break;
                }
                self.index += 1;
            }

            if (self.index == self.buffer.len) {
                return LexError.UnterminatedMultilineComment;
            }

            token.loc.end = self.index;
            return token;
        }

        if (self.index >= self.buffer.len) {
            token.tag = .eof;
            token.loc.end = self.index;
            return token;
        }

        switch (self.peek()) {
            '(' => {
                token.tag = .openParen;
                self.index += 1;
                return token;
            },
            ')' => {
                token.tag = .closeParen;
                self.index += 1;
                return token;
            },
            '{' => {
                token.tag = .openBrace;
                self.index += 1;
                return token;
            },
            '}' => {
                token.tag = .closeBrace;
                self.index += 1;
                return token;
            },
            ';' => {
                token.tag = .semicolon;
                self.index += 1;
                return token;
            },
            '0'...'9' => {
                token.tag = .numberLiteral;
                while (self.index < self.buffer.len and isDigit(self.peek())) {
                    self.index += 1;
                }

                if (self.index < self.buffer.len and isAlpha(self.peek())) {
                    return LexError.InvalidConstant;
                }

                token.loc.end = self.index;
                return token;
            },
            'a'...'z', 'A'...'Z', '_' => {
                while (self.index < self.buffer.len and (isAlphanumeric(self.peek()) or self.peek() == '_')) {
                    self.index += 1;
                }

                token.tag = Lexer.getIdentifierTag(self.buffer[token.loc.start..self.index]);
                token.loc.end = self.index;
                return token;
            },

            else => {
                self.index += 1;
                return LexError.UnsupportedToken;
            },
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

            const token_copy = Token{ .tag = token.tag, .loc = .{ .start = token.loc.start, .end = token.loc.end } };
            tokens.append(token_copy) catch {
                return LexError.OutOfMemory;
            };
        }

        return tokens;
    }
};
