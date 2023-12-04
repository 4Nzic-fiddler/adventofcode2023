const std = @import("std");
const ascii = std.ascii; // for .isDigit() but I really hate assuming ascii
const expect = std.testing.expect;

pub fn isAdjacentToSymbol(lines: *[3][1000]u8, i: u64, line_len:u64) bool {
    const low:u64 = if (i > 0) i - 1 else 0;
    const high:u64 = if (i < line_len - 1) i + 2 else line_len;
    for (0..3) |linenum| {
        for (low..high) |j| {
            const c:u8 = lines[linenum][j];
            //std.debug.print("Character at {d},{d}: {c}\n", .{linenum, j, c});
            if (!ascii.isDigit(c) and !(c == '.')) {
                //std.debug.print("Found adjacent symbol: {c}\n", .{c});
                return true;
            }
        }
    }
    return false;
}


pub fn getSumOfPartNumbersAdjacent(lines: *[3][1000]u8, line_len: u64) u32 {
    var sum_of_part_nums:u32 = 0;
    var current_num:u32 = 0;
    var is_adjacent:bool = false;
    // Go from left to right inspecting the current line for digits
    for (0..line_len) |i| {
        const c:u8 = lines[1][i];
        if (ascii.isDigit(c)) {
            current_num = current_num * 10 + (c - '0');
            // Sweep in a 3x3 grid around the current character to see if any adjacent characters are symbols
            if (isAdjacentToSymbol(lines, i, line_len)) {
                is_adjacent = true;
            }
        } else if (current_num > 0){
            if (is_adjacent) {
                sum_of_part_nums += current_num;
                std.debug.print("Found adjacent number: {d}\n", .{current_num});
            }
            current_num = 0;
            is_adjacent = false;
        }
    }
    // Handle the special case where the last character in the line is a digit
    if (current_num > 0) {
        if (is_adjacent or isAdjacentToSymbol(lines, line_len - 1, line_len)) {
            sum_of_part_nums += current_num;
        }
    }
    
    return sum_of_part_nums;
}


pub fn push_line(lines: *[3][1000]u8, line: *const [] u8, push_blank:bool) void {
    // Shift the lines up, discarding the oldest line at index 0
    // Note that we have to actually copy the data values, not just move
    // the pointers, because the memory for the lines is reused as each 
    // new line is read.
    std.mem.copy(u8, &lines[0], &lines[1]);
    std.mem.copy(u8, &lines[1], &lines[2]);
    if (push_blank) {
        @memset(&lines[2], '.');
    } else {
        std.mem.copy(u8, &lines[2], line.*);
    }
    
}

pub fn getFirstLineLen(filename: []const u8) !u64 {
    // Open input file and schedule closing it at the end of this block
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    // Create a 4k buffer to read lines into
    var buf: [4096]u8 = undefined;

    var first_line_len: u64 = 0;
    // Get the first line, just so we know how long it is
    var dummyline = try in_stream.readUntilDelimiterOrEof(&buf, '\n');
    // Make sure we actually got a line before operating on it
    if (dummyline) |line| {
        first_line_len = line.len;
    } else { 
        // If we couldn't even read the first line, return 0
        return 0;
    }
    return first_line_len;
}



pub fn solvePartOne() !u32 {
    var sum_of_part_nums:u32 = 0;
    const filename = "input.txt";
    // We only need to keep track of three lines of input at a time:
    // 0: the previous line (or a line of all . if we're on the first line)
    // 1: the current line
    // 2: the next line (or a line of all . if we're on the last line)
    const MAX_LINE_LEN: u64 = 1000;
    var lines: [3][MAX_LINE_LEN]u8 = undefined; // let's use an array of 3 pointers to arrays of u8
    lines[0] = [_]u8{'.'} ** MAX_LINE_LEN; 
    lines[1] = [_]u8{'.'} ** MAX_LINE_LEN; 
    lines[2] = [_]u8{'.'} ** MAX_LINE_LEN; 
    // Open input file and schedule closing it at the end of this block
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    // Create a 4k buffer to read lines into
    var buf: [4096]u8 = undefined;

    const first_line_len: u64 = try getFirstLineLen(filename);

    // Read lines from stdin until EOF is reached. Lines are delimited by '\n'
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len > 0) {
            // DEBUG: Print the line for manual review
            std.debug.print("\nline: {s}\n", .{line});
            push_line(&lines, &line, false);
            sum_of_part_nums += getSumOfPartNumbersAdjacent(&lines, first_line_len);
        }
    }
    // Special case for the last line: we need to push a line of all . and find the last adjacent part numbers
    var dummy:*const []u8 = undefined;
    push_line(&lines, dummy, true);
    sum_of_part_nums += getSumOfPartNumbersAdjacent(&lines, first_line_len);
    return sum_of_part_nums;
}

pub fn main() !void {
    // Part One
    const answerOne:u32 = try solvePartOne();
    std.debug.print("Part One Answer: {d}\n", .{answerOne});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
