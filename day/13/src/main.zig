const std = @import("std");
const ArrayList = std.ArrayList;
const expect = std.testing.expect;

/// returns true if there is only 1 binary bit flipped
/// between n1 and n2, for example 8 and 12 are different
/// only in the 8's place
pub fn oneBitDifference(n1:u64, n2:u64) bool {
    var x1:u64 = 1; // x1 will have just one bit set
    for (0..65) |i| {
        _ = i;
        if (n1 ^ x1 == n2) {
            return true;
        }
        x1 = x1 << 1; // shift the 1 bit left by one
    }
    return false;
}
test "one bit difference" {
    try expect(oneBitDifference(8, 12) == true);
    try expect(oneBitDifference(14869, 10773) == true);
    try expect(oneBitDifference(5, 37) == true);
}

/// returns the index of the row just PAST the reflection line
/// which is between rows. That makes the math easy for computing
/// the number of rows above the line or left of the line, which is
/// the same as the index, and it means the number 0 can be reserved
/// to mean "no reflection"
pub fn getReflectionIndex(list:ArrayList(u64), smudges_allowed:u8) usize {
    var items = list.items;
    var reflection_at_index:usize = 0;
    var smudges_found:u8 = 0;
    for (1..items.len) |i| { // i is index
        smudges_found = 0; // reset for each index we check
        reflection_at_index = i; // assume reflection until proven false
        for (0..i+1) |j| {
            if (i-j==0 or i+j >= items.len) break;
            const check_index1 = i-j-1;
            const check_index2 = i+j;
            //std.debug.print("checking if items[{d}] ({d}) == items[{d}] ({d})\n", .{check_index1, items[check_index1], check_index2, items[check_index2]});
            if (items[check_index1] != items[check_index2]) {
                // Not a reflection, but check if a smudge fix would MAKE this a reflection
                if (smudges_found < smudges_allowed and oneBitDifference(items[check_index1], items[check_index2])) {
                    smudges_found += 1;
                    std.debug.print("Fixed a smudge to make items[{d}] ({d}) == items[{d}] ({d})!\n", .{check_index1, items[check_index1], check_index2, items[check_index2]});
                } else {
                    reflection_at_index = 0;
                    break; 
                }
            }
        }
        // If a reflection was found, return it
        if (reflection_at_index > 0 and smudges_found == smudges_allowed) {
            break;
        }
    }
    // REQUIRE a smudge to be fixed if one was requested
    if (smudges_found != smudges_allowed) {
        reflection_at_index = 0;
    }
    return reflection_at_index;
}
test "reflection index" {
    const allocator = std.testing.allocator;
    var list = ArrayList(u64).init(allocator);
    defer{list.deinit();}
    try list.append(1);
    try list.append(1);
    try list.append(2);
    try list.append(8);
    try list.append(5);
    const refl = getReflectionIndex(list, 0);
    std.debug.print("Reflection index: {d}\n", .{refl});
    try expect(refl==1);

    var list2 = ArrayList(u64).init(allocator);
    defer{list2.deinit();}
    try list2.append(50);
    try list2.append(1);
    try list2.append(23);
    try list2.append(8);
    try list2.append(8);
    const refl2 = getReflectionIndex(list2, 0);
    std.debug.print("Reflection index: {d}\n", .{refl2});
    try expect(refl2==4);
}


pub fn getReflection(rows:ArrayList(u64), cols:ArrayList(u64), smudges_allowed:u8) u64 {
    // Find horizontal reflections in rows first
    var total_reflection:u64 = 0;
    std.debug.print("Checking Rows: ", .{});
    const reflection_row = getReflectionIndex(rows, smudges_allowed);
    if (reflection_row > 0) {
        total_reflection = (reflection_row) * 100;
    }
    std.debug.print("Checking Cols: ", .{});
    const reflection_col = getReflectionIndex(cols, smudges_allowed);
    if (reflection_row > 0 and reflection_col > 0) {
        std.debug.print("This grid has reflections horizontally and vertically!", .{});
    }
    if (reflection_col > 0) {
        total_reflection += reflection_col;
    }
    
    // Debug if total_reflection is 0
    if (total_reflection == 0) {
        std.debug.print("ROWS:\n", .{});
        for (0..rows.items.len) |r| {
            std.debug.print("{d}: {d}\n", .{r, rows.items[r]});
        }
        std.debug.print("COLS:\n", .{});
        for (0..cols.items.len) |c| {
            std.debug.print("{d}: {d}\n", .{c, cols.items[c]});
        }
    }
    return total_reflection; // if no reflections in rows or cols, this is 0
}

pub fn solvePart(part_num:u8) !u64 {
    const allocator = std.heap.page_allocator;
    var rows = std.ArrayList(u64).init(allocator);
    var cols = std.ArrayList(u64).init(allocator);
    // We wil deinit these between each map

    var part_answer:u64 = 0;
    std.debug.print("\n\nPart {d}\n", .{part_num});

    // Open input file and schedule closing it at the end of this block
    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    // Create a 4k buffer to read lines into
    var buf: [4096]u8 = undefined;

    // Read each line turn rows into numbers where # represents 1 and . represents 0
    // Read lines from stdin until EOF is reached. Lines are delimited by '\n'
    var line_num:usize = 0;
    var row_num:usize = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        line_num += 1;
        std.debug.print("{d}:\t{s}\n", .{row_num, line});
        row_num += 1;
        var trimmed_line = std.mem.trim(u8, line, " ");
        if (trimmed_line.len == 0) {
            const reflection_num = getReflection(rows, cols, part_num-1);
            std.debug.print("Reflection Number: {d}\n", .{reflection_num});
            part_answer += reflection_num;
            rows.deinit();
            cols.deinit();
            row_num = 0;
            // start with new lists (faster than removing all values)
            rows = std.ArrayList(u64).init(allocator);
            cols = std.ArrayList(u64).init(allocator);
            continue;
        }
        
        var row_hash:u64 = 0; // row hash will be built here
        var col_num:usize = 0;
        for (trimmed_line) |char| {
            if (rows.items.len == 0) {
                // First row, so we need to start each column
                try cols.append(0);
            }
            row_hash = row_hash << 1; // shift left
            cols.items[col_num] = cols.items[col_num] << 1; // shift left
            // # is 1, . is 0, so add 1 or 0 and shift result left
            if (char=='#') {
                row_hash += 1;
                cols.items[col_num] += 1;
            } else if (char!='.') {
                std.debug.print("Found invalid character: {c} at {d}, {d}\n", .{char, line_num, col_num});
            }
            col_num += 1;
        }
        try rows.append(row_hash);
    }
    
    std.debug.print("Sum of reflection numbers (part {d}): {d}\n", .{part_num, part_answer});
    return part_answer;
}

pub fn main() !void {
    const part_one = try solvePart(1);
    std.debug.print("Part 1: {d}", .{part_one});
    const part_two = try solvePart(2); // 44286 is too high, 31839 is too LOW, 37590 is too HIGH
    std.debug.print("Part 2: {d}", .{part_two});
}
