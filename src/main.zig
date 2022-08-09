const std = @import("std");
const Regex = @import("regex").Regex;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var iter = try std.process.argsWithAllocator(allocator);
    defer iter.deinit();

    const prog = iter.nextPosix().?;
    const pattern = iter.nextPosix() orelse {
        std.log.err("usage: {s} \"[pattern]\"", .{prog});

        return error.InvalidArgs;
    };

    // std.debug.print("prog: {s}\n", .{prog});
    // std.debug.print("pattern: {s}\n", .{pattern});

    const stdout = std.io.getStdOut();

    var regex = try Regex.compile(allocator, pattern);

    var arg = iter.nextPosix();
    if (arg == null) {
        const stdin = std.io.getStdIn();
        grep(stdin, stdout, &regex) catch |err| {
            std.log.warn("error reading stdin : {}", .{err});
        };

        return;
    }

    while (true) : (arg = iter.nextPosix()) {
        if (arg == null) {
            break;
        }

        // std.debug.print("{s}\n", .{arg.?});

        const file = try std.fs.cwd().openFile(arg.?, .{ .read = true, .write = false });
        defer file.close();
        grep(file, stdout, &regex) catch |err| {
            std.log.warn("error reading file '{s}': {}", .{ arg.?, err });
        };
    }
}

fn grep(in: std.fs.File, out: std.fs.File, regex: *Regex) anyerror!void {
    const reader = in.reader();
    const writer = out.writer();

    var buf: [std.mem.page_size]u8 = undefined;
    var i: u32 = 1;
    while (true) : (i += 1) {
        var line = reader.readUntilDelimiterOrEof(buf[0..buf.len], '\n') catch null;
        if (line == null) {
            break;
        }

        if (try regex.partialMatch(line.?)) {
            try writer.print("{}:{s}\n", .{ i, line.? });
        }
    } else |err| {
        std.log.warn("{}", .{err});
    }
}
