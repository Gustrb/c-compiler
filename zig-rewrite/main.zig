const std = @import("std");
const cli = @import("cli.zig");
const lex = @import("lex.zig");
const io = std.io;
const process = std.process;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    const stderr = io.getStdErr().writer();

    // Parse args into string array (error union needs 'try')
    const args = std.process.argsAlloc(allocator) catch {
        try stderr.print("[Error]: Failed to allocate memory for args\n", .{});
        try process.exit(1);
    };

    defer std.process.argsFree(allocator, args);

    // Parse the command line arguments
    const cliArgs = cli.parseCliArgs(args) catch |err| {
        if (err == cli.CLIError.InvalidNumberOfArguments) {
            try stderr.print("[Error]: Invalid number of arguments\n", .{});
            try cli.printUsage();
        } else if (err == cli.CLIError.InvalidFlag) {
            try stderr.print("[Error]: Invalid flag\n", .{});
            try cli.printUsage();
        } else {
            try stderr.print("[Error]: Unknown error\n", .{});
        }

        try process.exit(1);
    };

    var file = std.fs.cwd().openFile(cliArgs.inputFilepath, .{}) catch {
        try stderr.print("[Error]: Failed to open file: {s}\n", .{cliArgs.inputFilepath});
        try process.exit(1);
    };

    defer file.close();

    const stat = file.stat() catch {
        try stderr.print("[Error]: Failed to get file stat for file: {s}\n", .{cliArgs.inputFilepath});
        try process.exit(1);
    };

    const buffer = file.readToEndAlloc(allocator, stat.size) catch {
        try stderr.print("[Error]: Failed to read {s} file into buffer\n", .{cliArgs.inputFilepath});
        try process.exit(1);
    };

    defer allocator.free(buffer);

    if (cliArgs.state == cli.State.upToLex) {
        _ = lex.Lexer.lexWholeFile(allocator, buffer) catch |err| {
            try stderr.print("[Error]: Failed to lex file: {s}, {}\n", .{ cliArgs.inputFilepath, err });
            try process.exit(1);
        };
    }
}
