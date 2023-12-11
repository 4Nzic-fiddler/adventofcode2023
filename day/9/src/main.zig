const std = @import("std");

pub fn predictNextNumber(number_list:std.ArrayList(i32)) !i32 {
    var next_list:std.ArrayList(i32) = std.ArrayList(i32).init(std.heap.page_allocator);
    var last_number:i32 = 0;
    var skipped_first_number:bool = false;
    var all_are_zero:bool = true;
    for (number_list.items) |number| {
        if (number != 0) {
            all_are_zero = false;
        }
        if (skipped_first_number) {
            try next_list.append(number - last_number);
        } else {
            skipped_first_number = true;
        }
        last_number = number;
    }
    if (all_are_zero) {
        return 0;
    } 
    return try predictNextNumber(next_list) + number_list.items[number_list.items.len - 1];
}

pub fn solvePart(part_num:u8) !i32 {
    var sum_of_prediction_numbers:i32 = 0; // this will be the answer to part one
    // Open input file and schedule closing it at the end of this block
    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    // Create a 4k buffer to read lines into
    var buf: [4096]u8 = undefined;

    // Read each line of numbers separated by spaces into a list and predict the next number in sequence
    // Read lines from stdin until EOF is reached. Lines are delimited by '\n'
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var trimmed_line = std.mem.trim(u8, line, " ");
        if (trimmed_line.len > 0) {
            var number_list = std.ArrayList(i32).init(std.heap.page_allocator);
            defer number_list.deinit();
            var token_iterator = std.mem.split(u8, trimmed_line, " ");
            while (token_iterator.next()) |number_string| {
                var number:i32 = try std.fmt.parseInt(i32, number_string, 10);
                try number_list.append(number);
            }
            var predicted_number:i32 = try predictNextNumber(number_list);
            sum_of_prediction_numbers += predicted_number;
        }
    }
    if (part_num == 1) {
        return sum_of_prediction_numbers;
    } else {
        return 0;
    }
    
}

pub fn main() !void {
    const sum_of_predictions:i32 = try solvePart(1);
    std.debug.print("Answer to part one: {d}\n", .{sum_of_predictions});
    
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
