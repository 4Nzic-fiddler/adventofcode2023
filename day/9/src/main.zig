const std = @import("std");

pub fn predictNextNumber(number_list:std.ArrayList(i32), direction:i32) !i32 {
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
    var adjacent_number:i32 = 0;
    if (direction > 0) {
        adjacent_number = number_list.items[number_list.items.len - 1];
    } else {
        adjacent_number = number_list.items[0];
    }
    return try predictNextNumber(next_list, direction)*direction + adjacent_number;
}

pub fn solvePart(part_num:u8) !i32 {
    var sum_of_prediction_numbers:i32 = 0; // this will be the answer to part one
    var direction:i32 = 1;
    if (part_num == 1) {
        direction = 1; // predict forward (next value in sequence) for part 1
    } else {
        direction = -1; // predict backward (previous value in sequence) for part 2
    }
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
            var predicted_number:i32 = try predictNextNumber(number_list, direction);
            sum_of_prediction_numbers += predicted_number;
        }
    }
    
    return sum_of_prediction_numbers;
    
}

pub fn main() !void {
    const sum_of_predictions:i32 = try solvePart(1);
    std.debug.print("Answer to part one: {d}\n", .{sum_of_predictions});
    
    const sum_of_predictions2:i32 = try solvePart(2);
    std.debug.print("Answer to part two: {d}\n", .{sum_of_predictions2});    
}

