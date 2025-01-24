// Note: This is just a plain rewrite of the original code, it sucks, but it's a start, when I have some time
//       I'll make this data oriented to make it faster.
const std = @import("std");
const io = std.io;
const lex = @import("lex.zig");

const Token = lex.Token;
const TokenTag = lex.Token.Tag;

pub const ConstantExpression = struct {
    value: u64,
};

pub const Expression = struct {
    pub const Tag = enum { constant };

    tag: Tag,
    value: union {
        Constant: *ConstantExpression,
    },
};

pub const ReturnStatement = struct {
    expression: *Expression,
};

pub const Statement = struct {
    pub const Tag = enum {
        Return,
    };

    tag: Tag,
    value: union {
        Return: *ReturnStatement,
    },
};

pub const FunctionDefinition = struct { name: []const u8, stmt: *Statement };
pub const Program = struct { function: *FunctionDefinition };

pub const ParseError = error{ UnexpectedToken, OutOfMemory, FunctionNameTooLong };

pub const Parser = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    lexer: lex.Lexer,

    pub fn init(allocator: std.mem.Allocator, data: []const u8) Self {
        return Self{ .allocator = allocator, .lexer = lex.Lexer.init(data) };
    }

    fn nextToken(self: *Self) lex.LexError!Token {
        return self.lexer.next();
    }

    fn parserExpect(self: *Self, tag: TokenTag, processedToken: *Token) ParseError!void {
        const stderr = io.getStdErr().writer();
        processedToken.* = self.nextToken() catch |err| {
            switch (err) {
                lex.LexError.UnsupportedToken => {
                    const loc = self.lexer.getErrorLineAndCol(processedToken.*);
                    stderr.print("[Error]: Unkwnown token at {}:{}\n", .{ loc.line, loc.col }) catch {};
                    return ParseError.UnexpectedToken;
                },
                lex.LexError.InvalidConstant => {
                    const loc = self.lexer.getErrorLineAndCol(processedToken.*);
                    stderr.print("[Error]: Invalid constant at {}:{}\n", .{ loc.line, loc.col }) catch {};
                    return ParseError.UnexpectedToken;
                },
                lex.LexError.UnterminatedMultilineComment => {
                    const loc = self.lexer.getErrorLineAndCol(processedToken.*);
                    stderr.print("[Error]: Unterminated multiline comment at {}:{}\n", .{ loc.line, loc.col }) catch {};
                    return ParseError.UnexpectedToken;
                },
                lex.LexError.OutOfMemory => {
                    stderr.print("[Error]: Out of memory\n", .{}) catch {};
                    return ParseError.OutOfMemory;
                },
            }
        };

        if (processedToken.*.tag != tag) {
            return ParseError.UnexpectedToken;
        }
    }

    fn parseConstantExpression(self: *Self) ParseError!*ConstantExpression {
        var constantExpr = self.allocator.create(ConstantExpression) catch {
            return ParseError.OutOfMemory;
        };

        var token = Token{ .tag = TokenTag.invalid, .loc = .{ .start = 0, .end = 0 } };
        try self.parserExpect(TokenTag.numberLiteral, &token);

        constantExpr.value = 0;
        for (token.loc.start..token.loc.end) |i| {
            const digit = self.lexer.buffer[i];
            if (digit < '0' or digit > '9') {
                return ParseError.UnexpectedToken;
            }

            constantExpr.value = constantExpr.value * 10 + (digit - '0');
        }

        return constantExpr;
    }

    fn parseExpression(self: *Self) ParseError!*Expression {
        var expr = self.allocator.create(Expression) catch {
            return ParseError.OutOfMemory;
        };

        // We only support constant expressions for now
        expr.tag = Expression.Tag.constant;
        expr.value.Constant = try self.parseConstantExpression();

        return expr;
    }

    fn parseReturnStatement(self: *Self) ParseError!*ReturnStatement {
        var returnStmt = self.allocator.create(ReturnStatement) catch {
            return ParseError.OutOfMemory;
        };

        var token = Token{ .tag = TokenTag.invalid, .loc = .{ .start = 0, .end = 0 } };
        try self.parserExpect(TokenTag.keywordReturn, &token);

        returnStmt.expression = try self.parseExpression();

        try self.parserExpect(TokenTag.semicolon, &token);

        return returnStmt;
    }

    fn parseStatement(self: *Self) ParseError!*Statement {
        var stmt = self.allocator.create(Statement) catch {
            return ParseError.OutOfMemory;
        };

        // We only support return statements for now
        stmt.tag = Statement.Tag.Return;
        stmt.value.Return = try self.parseReturnStatement();

        return stmt;
    }

    pub fn parse(self: *Self) ParseError!Program {
        var function = self.allocator.create(FunctionDefinition) catch {
            return ParseError.OutOfMemory;
        };

        var token = Token{ .tag = TokenTag.invalid, .loc = .{ .start = 0, .end = 0 } };
        try self.parserExpect(TokenTag.keywordInt, &token);
        try self.parserExpect(TokenTag.identifier, &token);

        // assert function name length
        if (token.loc.end - token.loc.start > 255) {
            const loc = self.lexer.getErrorLineAndCol(token);
            const stderr = io.getStdErr().writer();
            stderr.print("[Error]: Function name too long at {}:{}\n", .{ loc.line, loc.col }) catch {};
            return ParseError.FunctionNameTooLong;
        }

        function.name = self.lexer.buffer[token.loc.start..token.loc.end];

        try self.parserExpect(TokenTag.openParen, &token);
        try self.parserExpect(TokenTag.keywordVoid, &token);
        try self.parserExpect(TokenTag.closeParen, &token);
        try self.parserExpect(TokenTag.openBrace, &token);

        function.stmt = try self.parseStatement();

        try self.parserExpect(TokenTag.closeBrace, &token);
        const program = Program{ .function = function };
        try self.parserExpect(TokenTag.eof, &token);

        return program;
    }
};
