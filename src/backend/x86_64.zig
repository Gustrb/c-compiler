pub const std = @import("std");
const builtin = @import("builtin");
pub const codegen = @import("../codegen.zig");

pub const AssemblyGenerationError = error{
    InvalidRegister,
    FailedToCreateOutputFile,
    FaileToWriteOutputFile,
    InvalidMovAdressingMode,
};

pub fn getRegisterByName(reg: u64) AssemblyGenerationError![]const u8 {
    switch (reg) {
        0 => return "eax",
        else => return AssemblyGenerationError.InvalidRegister,
    }
}

pub const X86_64 = struct {
    const Self = @This();
    allocator: std.mem.Allocator,

    pub fn x86_64GenAssembly(self: *Self, outputPath: []const u8, program: codegen.Program) AssemblyGenerationError!void {
        // First, let's open the file
        const file = std.fs.cwd().createFile(outputPath, .{}) catch {
            return AssemblyGenerationError.FailedToCreateOutputFile;
        };
        defer file.close();

        try self.x86_64EmitFunction(file.writer(), program.functionDefinition);
    }

    fn x86_64EmitFunction(self: *Self, writer: std.fs.File.Writer, function: codegen.FunctionDefinition) AssemblyGenerationError!void {
        const symbolPrefix: []const u8 = if (comptime builtin.os.tag == .macos) "_" else "";

        // Emit Label
        writer.print(".globl {s}{s}\n", .{ symbolPrefix, function.identifier }) catch {
            return AssemblyGenerationError.FaileToWriteOutputFile;
        };

        writer.print("{s}{s}:\n", .{ symbolPrefix, function.identifier }) catch {
            return AssemblyGenerationError.FaileToWriteOutputFile;
        };

        try self.x86_64EmitInstructions(writer, function.instructions);
    }

    fn x86_64EmitInstructions(self: *Self, writer: std.fs.File.Writer, instructions: codegen.InstructionList) AssemblyGenerationError!void {
        defer instructions.deinit();

        for (instructions.items) |instruction| {
            switch (instruction.tag) {
                codegen.Instruction.Tag.ret => {
                    try x86_64EmitRetInstruction(writer);
                    self.allocator.destroy(instruction.value.retInstruction);
                },
                codegen.Instruction.Tag.mov => {
                    try x86_64EmitMovInstruction(writer, instruction.value.moveInstruction.*);
                    self.allocator.destroy(instruction.value.moveInstruction);
                },
            }
        }
    }

    fn x86_64EmitRetInstruction(writer: std.fs.File.Writer) AssemblyGenerationError!void {
        writer.print("\tret\n", .{}) catch {
            return AssemblyGenerationError.FaileToWriteOutputFile;
        };
    }

    fn x86_64EmitMovInstruction(writer: std.fs.File.Writer, instruction: codegen.MovInstruction) AssemblyGenerationError!void {
        if (instruction.src.tag == codegen.Operand.Tag.immediate and instruction.dst.tag == codegen.Operand.Tag.register) {
            const register = try getRegisterByName(instruction.dst.value.register);
            writer.print("\tmovl ${d}, %{s}\n", .{ instruction.src.value.immediate, register }) catch {
                return AssemblyGenerationError.FaileToWriteOutputFile;
            };
        } else {
            return AssemblyGenerationError.InvalidMovAdressingMode;
        }
    }
};
