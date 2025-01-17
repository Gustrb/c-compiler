const std = @import("std");
const ArrayList = std.ArrayList;

const Parser = @import("parser.zig").Parser;
const ParseError = @import("parser.zig").ParseError;
const Ast = @import("parser.zig");

pub const MovInstruction = struct {
    pub const Operand = struct {
        pub const Tag = enum {
            register,
            immediate,
        };

        pub const Value = union {
            register: u64,
            immediate: u64,
        };

        tag: Tag,
        value: Value,
    };

    src: Operand,
    dst: Operand,
};

pub const RetInstruction = struct {};

pub const Instruction = struct {
    pub const Tag = enum {
        mov,
        ret,
    };

    pub const Value = union {
        moveInstruction: *MovInstruction,
        retInstruction: *RetInstruction,
    };

    tag: Tag,
    value: Value,
};

pub const InstructionList = ArrayList(Instruction);

pub const FunctionDefinition = struct {
    identifier: []const u8,
    instructions: InstructionList,
};

pub const Program = struct {
    functionDefinition: FunctionDefinition,
};

pub const CodegenError = error{
    FailedToParse,
    OutOfMemory,
};

pub const Codegen = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    parser: Parser,

    pub fn init(allocator: std.mem.Allocator, parser: Parser) Self {
        return Codegen{
            .allocator = allocator,
            .parser = parser,
        };
    }

    fn emitRetInstruction(instructions: *InstructionList) CodegenError!void {
        var ret = RetInstruction{};

        instructions.append(Instruction{ .tag = Instruction.Tag.ret, .value = Instruction.Value{ .retInstruction = &ret } }) catch {
            return CodegenError.OutOfMemory;
        };
    }

    fn emitMovInstruction(src: MovInstruction.Operand, dst: MovInstruction.Operand, instructions: *InstructionList) CodegenError!void {
        var mov = MovInstruction{
            .src = src,
            .dst = dst,
        };

        instructions.append(Instruction{ .tag = Instruction.Tag.mov, .value = Instruction.Value{ .moveInstruction = &mov } }) catch {
            return CodegenError.OutOfMemory;
        };
    }

    fn genExpression(expression: *Ast.Expression, instructions: *InstructionList) CodegenError!void {
        switch (expression.tag) {
            Ast.Expression.Tag.constant => {
                const constant = expression.value.Constant;
                const src = MovInstruction.Operand{ .tag = MovInstruction.Operand.Tag.immediate, .value = MovInstruction.Operand.Value{ .immediate = constant.value } };
                const dst = MovInstruction.Operand{ .tag = MovInstruction.Operand.Tag.register, .value = MovInstruction.Operand.Value{ .register = 0 } };

                try Self.emitMovInstruction(src, dst, instructions);
            },
        }
    }

    fn genStatement(statement: *Ast.Statement, instructions: *InstructionList) CodegenError!void {
        switch (statement.tag) {
            Ast.Statement.Tag.Return => {
                try Self.genExpression(statement.value.Return.expression, instructions);
                try Self.emitRetInstruction(instructions);
            },
        }
    }

    fn genFunctionDefinition(self: *Self, functionDefinition: *Ast.FunctionDefinition) CodegenError!FunctionDefinition {
        var fdef = FunctionDefinition{
            .identifier = functionDefinition.name,
            .instructions = InstructionList.init(self.allocator),
        };

        try Self.genStatement(functionDefinition.stmt, &fdef.instructions);
        return fdef;
    }

    pub fn genProgram(self: *Self) CodegenError!Program {
        const p = self.parser.parse() catch |err| {
            switch (err) {
                ParseError.UnexpectedToken, ParseError.OutOfMemory, ParseError.FunctionNameTooLong => return CodegenError.FailedToParse,
            }
        };

        return Program{
            .functionDefinition = try self.genFunctionDefinition(p.function),
        };
    }
};
