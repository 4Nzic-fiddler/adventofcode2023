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

// This is a struct to hold a coordinate pair
// We use this to hold the coordinates of each gear
const Coord = struct {
    row: u64,
    col: u64,
};

const NoCoordError = error {
    NoCoord,
};

// This is like isAdjacentToSymbol, but it only checks for adjacent gears (*) and returns the gear coord if true
// or NoCoordError if false. Pass in line_number, which is the line number of the input file, so that we can calculate
// a unique gear id.
pub fn isAdjacentToGear(line_number:u64, lines: *[3][1000]u8, i: u64, line_len:u64) NoCoordError ! Coord {
    const low:u64 = if (i > 0) i - 1 else 0;
    const high:u64 = if (i < line_len - 1) i + 2 else line_len;
    for (0..3) |linedelta| {
        for (low..high) |j| {
            const c:u8 = lines[linedelta][j];
            //std.debug.print("Character at {d},{d}: {c}\n", .{linenum, j, c});
            if (c == '*') { // '*' is the symbol for a gear
                const gear_line_number:u64 = line_number + linedelta - 1;
                const gear_coord = Coord{.row = gear_line_number, .col = j+1};
                //std.debug.print("Found adjacent gear: {c} at ({d},{d})\n", .{c, gear_coord.row, gear_coord.col});
                return gear_coord;
            }
        }
    }
    return NoCoordError.NoCoord;
}

pub fn updateGearMap(gears_map:*std.AutoHashMap(Coord, [3]u32), gear_coord:Coord, part_num:u32) !void {
    var gear_part_nums = try gears_map.getOrPut(gear_coord);
    if (!gear_part_nums.found_existing) {
        gear_part_nums.value_ptr.* = [3]u32{0,0,0};
    }
    //std.debug.print("Adding {d} to gear at {d},{d}\n", .{current_num, gear_coord.row, gear_coord.col});
    for (0..3) |i| {
        if (gear_part_nums.value_ptr.*[i] == 0) {
            gear_part_nums.value_ptr.*[i] = part_num;
            break;
        }
    }
}

// This function handles a single line, getting the sum of all part numbers
// that are adjacent to a symbol (i.e. not a digit or a period)
// It requires the lines before and after the current line to be passed in
pub fn getSumOfPartNumbersAdjacent(lines: *[3][1000]u8, line_len: u64, gears_map:*std.AutoHashMap(Coord, [3]u32), line_num:u32) !u32 {
    var sum_of_part_nums:u32 = 0;
    var current_num:u32 = 0;
    var is_adjacent:bool = false;
    // As we parse numbers digit by digit, we need to keep track of the Coords of the gear(s)
    // that are adjacent to the part numbers. The list of Coords should be unique.
    // We need a Set data structure, but Zig doesn't have it, so we'll just use keys in a map
    const allocator = std.heap.page_allocator;
    var gears_found = std.AutoHashMap(Coord, u8).init(allocator);
    defer gears_found.deinit();
    // Go from left to right inspecting the current line for digits
    for (0..line_len) |i| {
        const c:u8 = lines[1][i];
        if (ascii.isDigit(c)) {
            current_num = current_num * 10 + (c - '0');
            // Sweep in a 3x3 grid around the current character to see if any adjacent characters are symbols
            if (isAdjacentToSymbol(lines, i, line_len)) {
                is_adjacent = true;
                // If it's adjacent to a gear, keep track of the gear's coords (for part 2)
                // TODO: I think there's a more zig style way to handle this error, and I thought it was
                // to let gear_coord be a union of Coord and NoCoordError, 
                // but when I tried that, if (gear_coord != NoCoordError.NoCoord) { gears_found.put(gear_coord.?, 1); } didn't work... hmmmm! 
                // So, for now, 9999,9999 means no coord.
                const gear_coord:Coord = isAdjacentToGear(line_num, lines, i, line_len) catch Coord{.row=9999, .col=9999};
                // if (gear_coord != NoCoordError.NoCoord) { gears_found.put(gear_coord.?, 1); } // this is what I wanted to work
                if (gear_coord.row != 9999 and gear_coord.col != 9999) {
                    try gears_found.put(gear_coord, 1); // hashmap takes care of uniquifying the keys
                }
            }
        } else if (current_num > 0){
            if (is_adjacent) {
                sum_of_part_nums += current_num;
                //std.debug.print("Found adjacent number: {d}\n", .{current_num});
                // If we found any adjacent gear(s), add the part number to the gear's list of adjacent part numbers
                var iterator = gears_found.keyIterator();
                while (iterator.next()) |gear_coord| {
                    try updateGearMap(gears_map, gear_coord.*, current_num);
                }
                
            }
            current_num = 0;
            is_adjacent = false;
            // Clear out the gears_found map for the next part number
            gears_found.deinit();
            gears_found = std.AutoHashMap(Coord, u8).init(allocator);
        }
    }
    // Handle the special case where the last character in the line is a digit
    if (current_num > 0) {
        if (is_adjacent or isAdjacentToSymbol(lines, line_len - 1, line_len)) {
            sum_of_part_nums += current_num;
            // If we found any adjacent gear(s), add the part number to the gear's list of adjacent part numbers
            var iterator = gears_found.keyIterator();
            while (iterator.next()) |gear_coord| {
                try updateGearMap(gears_map, gear_coord.*, current_num);
            }
            
        }
    }
    
    return sum_of_part_nums;
}


pub fn pushLine(lines: *[3][1000]u8, line: *const [] u8, push_blank:bool) void {
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


// Part One: solve(1)
// Part Two: solve(2)
pub fn solve(challenge_num:u8) !u32 {
    var sum_of_part_nums:u32 = 0; // for part 1
    var sum_of_gear_ratios:u32 = 0; // for part 2

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

    // Set up file reading
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    // Create a 4k buffer to read lines into
    var buf: [4096]u8 = undefined;

    // Assumption: the first line of the input file is the same length as all the other lines
    const first_line_len: u64 = try getFirstLineLen(filename);

    // For part two, we need to keep track of the gear ids we've seen and which part
    // numbers are adjacent to them. Note that we only need a max of three part numbers
    // to know whether there are exactly two adjacent part numbers, so we can use a
    // fixed-size array of length 3, which saves a lot of unnecessary allocations.
    const allocator = std.heap.page_allocator;
    var gears_map = std.AutoHashMap(Coord, [3]u32).init(allocator);
    defer gears_map.deinit();

    var line_num:u32 = 0;

    // Read lines from stdin until EOF is reached. Lines are delimited by '\n'
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len > 0) {
            // DEBUG: Print the line for manual review
            //std.debug.print("\nline: {s}\n", .{line});
            pushLine(&lines, &line, false);
            // getSumOfPartNumbersAdjacent() returns the sum of all part numbers that are adjacent to a symbol
            // and also updates the gears_map with the gear ids (keys) that have adjacent part numbers
            const line_sum_of_part_nums:u32 = try getSumOfPartNumbersAdjacent(&lines, first_line_len, &gears_map, line_num);
            sum_of_part_nums += line_sum_of_part_nums;
        }
        line_num += 1;
    }
    // Special case for the last line: we need to push a line of all . and find the last adjacent part numbers
    var dummy:*const []u8 = undefined;
    pushLine(&lines, dummy, true);
    const line_sum_of_part_nums:u32 = try getSumOfPartNumbersAdjacent(&lines, first_line_len, &gears_map, line_num);
    sum_of_part_nums += line_sum_of_part_nums;

    // return answer
    if (challenge_num == 1) {
        return sum_of_part_nums;
    } else if (challenge_num == 2) {
        // sum up all the gear ratios of gears with exactly 2 adjacent part numbers
        var iterator = gears_map.iterator();
        while (iterator.next()) |kv| {
            const gear_coord = kv.key_ptr.*;
            _ = gear_coord; // only needed for debug output
            const gear_part_nums = kv.value_ptr.*;
            // If there are exactly two adjacent part numbers, multiply them together to get the gear ratio
            if (gear_part_nums[0] != 0 and gear_part_nums[1] != 0 and gear_part_nums[2] == 0) {
                const gear_ratio:u32 = gear_part_nums[0] * gear_part_nums[1];
                //std.debug.print("Found gear with exactly 2 adjacent part numbers: {d} at {d},{d}\n", .{gear_ratio, gear_coord.row, gear_coord.col});
                sum_of_gear_ratios += gear_ratio;
            }
        }
        return sum_of_gear_ratios;
    }
    return 0;
}



pub fn main() !void {
    // Part One
    const answerOne:u32 = try solve(1);
    std.debug.print("\nPart One Answer: {d}\n", .{answerOne});
    

    // Part Two
    const answerTwo:u32 = try solve(2);
    std.debug.print("Part Two Answer: {d}\n", .{answerTwo});

}

