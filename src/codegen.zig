const std = @import("std");
const ArrayList = std.ArrayList;

const Parser = @import("parser.zig").Parser;
const ParseError = @import("parser.zig").ParseError;
const Ast = @import("parser.zig");

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

pub const MovInstruction = struct {
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

    fn emitRetInstruction(self: *Self, instructions: *InstructionList) CodegenError!void {
        const ret = self.allocator.create(RetInstruction) catch {
            return CodegenError.OutOfMemory;
        };

        instructions.append(Instruction{ .tag = Instruction.Tag.ret, .value = Instruction.Value{ .retInstruction = ret } }) catch {
            return CodegenError.OutOfMemory;
        };
    }

    fn emitMovInstruction(self: *Self, src: Operand, dst: Operand, instructions: *InstructionList) CodegenError!void {
        var mov = self.allocator.create(MovInstruction) catch {
            return CodegenError.OutOfMemory;
        };

        mov.src = src;
        mov.dst = dst;

        instructions.append(Instruction{ .tag = Instruction.Tag.mov, .value = Instruction.Value{ .moveInstruction = mov } }) catch {
            return CodegenError.OutOfMemory;
        };
    }

    fn genExpression(self: *Self, expression: *Ast.Expression, instructions: *InstructionList) CodegenError!void {
        switch (expression.tag) {
            Ast.Expression.Tag.constant => {
                const constant = expression.value.Constant;
                const src = Operand{ .tag = Operand.Tag.immediate, .value = Operand.Value{ .immediate = constant.value } };
                const dst = Operand{ .tag = Operand.Tag.register, .value = Operand.Value{ .register = 0 } };

                try self.emitMovInstruction(src, dst, instructions);
                self.allocator.destroy(constant);
            },
        }

        self.allocator.destroy(expression);
    }

    fn genStatement(self: *Self, statement: *Ast.Statement, instructions: *InstructionList) CodegenError!void {
        switch (statement.tag) {
            Ast.Statement.Tag.Return => {
                try self.genExpression(statement.value.Return.expression, instructions);
                try self.emitRetInstruction(instructions);
                self.allocator.destroy(statement.value.Return);
            },
        }

        self.allocator.destroy(statement);
    }

    fn genFunctionDefinition(self: *Self, functionDefinition: *Ast.FunctionDefinition) CodegenError!FunctionDefinition {
        var fdef = FunctionDefinition{
            .identifier = functionDefinition.name,
            .instructions = InstructionList.init(self.allocator),
        };

        try self.genStatement(functionDefinition.stmt, &fdef.instructions);
        self.allocator.destroy(functionDefinition);
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
