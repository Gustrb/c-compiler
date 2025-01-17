const std = @import("std");
const io = std.io;
const process = std.process;

//
// We support the following flags:
// - --lex: that only performs the lexical analysis(no output)
// - --parse: that performs the lexical and syntactic analysis(no output)
// - --codegen: that performs the lexical, syntactic and code generation analysis(no output)
// - -S: that performs the lexical, syntactic and code generation and assembly emission
// - <filename>: that generates the executable
//
pub const State = enum {
    upToLex,
    upToParse,
    upToCodegen,
    upToAssembly,
    upToBinary,
};

pub fn printUsage() !void {
    const stdout = io.getStdOut().writer();

    try stdout.print("Usage: zig-rewrite [flags] <filename>\n", .{});
    try stdout.print("Flags:\n", .{});
    try stdout.print("  --lex: that only performs the lexical analysis(no output)\n", .{});
    try stdout.print("  --parse: that performs the lexical and syntactic analysis(no output)\n", .{});
    try stdout.print("  --codegen: that performs the lexical, syntactic and code generation analysis(no output)\n", .{});
    try stdout.print("  -S: that performs the lexical, syntactic and code generation and assembly emission\n", .{});
    try stdout.print("  <filename>: that generates the executable\n", .{});
}

pub const CLIFlags = struct {
    const Self = @This();

    state: State,
    inputFilepath: []const u8,
};

pub const CLIError = error{
    InvalidNumberOfArguments,
    InvalidFlag,
};

// Parse the command line arguments and return the flags,
// might return an error if the flags are invalid
pub fn parseCliArgs(args: [][:0]u8) CLIError!CLIFlags {
    // if there are 2 args, the first one is the executable name and the second is the filepath
    if (args.len == 2) {
        return CLIFlags{ .state = .upToBinary, .inputFilepath = args[1] };
    }

    if (args.len != 3) {
        return CLIError.InvalidNumberOfArguments;
    }

    // Compare the flags
    var state = State.upToLex;
    if (std.mem.eql(u8, "--lex", args[1])) {
        state = State.upToLex;
    } else if (std.mem.eql(u8, "--parse", args[1])) {
        state = State.upToParse;
    } else if (std.mem.eql(u8, "--codegen", args[1])) {
        state = State.upToCodegen;
    } else if (std.mem.eql(u8, "-S", args[1])) {
        state = State.upToAssembly;
    } else {
        return CLIError.InvalidFlag;
    }

    return CLIFlags{ .state = state, .inputFilepath = args[2] };
}

pub fn findAssemblyOutputPath(inputPath: []const u8, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    // Here, we need to find the last . and replace it with .s
    var i: usize = inputPath.len - 1;
    while (i > 0) {
        if (inputPath[i] == '.') {
            break;
        }

        i -= 1;
    }

    // return slice from 0 to i
    const outpath = inputPath[0..i];
    const outpathWithExtension = try allocator.alloc(u8, outpath.len + 2);

    @memcpy(outpathWithExtension[0..outpath.len], outpath);

    outpathWithExtension[outpath.len] = '.';
    outpathWithExtension[outpath.len + 1] = 's';
    return outpathWithExtension;
}

pub fn findBinaryOutputPath(inputPath: []const u8) []const u8 {
    // Find last .
    var i: usize = inputPath.len - 1;
    while (i > 0) {
        if (inputPath[i] == '.') {
            break;
        }

        i -= 1;
    }

    // return slice from 0 to i
    return inputPath[0..i];
}
