const std = @import("std");

pub fn getCharacterAt(buffer: []const u8, row:usize, col:usize, row_length:usize) u8 {
    // note: we add 1 to row_length to account for the newline character
    const pos = row * (row_length+1) + col;
    if (pos >= buffer.len) {
        return 0;
    }
    return buffer[pos];
}

pub fn getRowLength(buffer: []const u8) usize {
    var i: usize = 0;
    while (buffer[i] != '\n') { 
        i += 1;
    }
    return i;
}

pub fn getColLength(buffer:[]const u8, row_length:usize) usize {
    return buffer.len / (row_length+1); // +1 accounts for the \n at the end of each row
}

pub fn solvePart(part_num:u8, buffer:[]const u8, row_length:usize, col_length:usize) u64 {
    var total_load:u64 = 0;
    
    if (part_num == 1) {
        // Roll all the rocks that can roll to the north
        // Let's take one column at a time
        for (0..row_length) |col_num| {
            var col_load:u64 = 0;
            // Each time we find a square rock #, we will
            // update north_rock_stops_at to be one row greater
            var north_rock_stops_at:u64 = 0;
            // We'll count the number of round rocks between
            // square rocks
            var num_round_rocks:u64 = 0;
            for (0..col_length) |row_num| {
                const rock_type:u8 = getCharacterAt(buffer, row_num, col_num, row_length);
                if (rock_type == 'O') {
                    num_round_rocks += 1;
                }
                if (row_num == col_length-1 or rock_type == '#') {
                    var rock_load:u64 = col_length - north_rock_stops_at;
                    while (num_round_rocks > 0) {
                        col_load += rock_load;
                        rock_load -= 1; // next rock is less load
                        num_round_rocks -= 1;
                    }
                    north_rock_stops_at = row_num+1; // new stopping point
                }
            }
            total_load += col_load;
            col_load = 0;
        }
    } else if (part_num == 2) {
        total_load = 0;
    }
    return total_load;
}

pub fn main() !void {
    // Get the size of the input file, allocate a buffer on the heap 
    // that is big enough to hold the entire file, and read the file
    var file = try std.fs.cwd().openFile("input.txt", .{ .mode = .read_only });
    const file_size = (try file.stat()).size;
    const allocator = std.heap.page_allocator;
    var buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    try file.reader().readNoEof(buffer);

    // Get the length of the first row
    const row_length = getRowLength(buffer);
    const col_length:usize = getColLength(buffer, row_length);
    std.debug.print("\nInput parsed: {d} rows, {d} cols\n", .{col_length, row_length});

    // Part 1 
    const answer_part_one = solvePart(1, buffer, row_length, col_length);
    std.debug.print("\nPart 1 answer (Total Load on North wall): {d}\n", .{answer_part_one});

}

