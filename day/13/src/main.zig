const std = @import("std");
const ArrayList = std.ArrayList;
const expect = std.testing.expect;

/// returns the index of the row just PAST the reflection line
/// which is between rows. That makes the math easy for computing
/// the number of rows above the line or left of the line, which is
/// the same as the index, and it means the number 0 can be reserved
/// to mean "no reflection"
pub fn getReflectionIndex(list:ArrayList(u64)) usize {
    var items = list.items;
    var reflection_at_index:usize = 0;
    for (1..items.len) |i| { // i is index
        reflection_at_index = i; // assume reflection until proven false
        for (0..i+1) |j| {
            if (i-j==0 or i+j >= items.len) break;
            const check_index1 = i-j-1;
            const check_index2 = i+j;
            if (items[check_index1] != items[check_index2]) {
                // Not a reflection, stop checking this index
                reflection_at_index = 0;
                break; 
            }
        }
        // If a reflection was found, return it
        if (reflection_at_index > 0) {
            break;
        }
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
    const refl = getReflectionIndex(list);
    std.debug.print("Reflection index: {d}\n", .{refl});
    try expect(refl==1);

    var list2 = ArrayList(u64).init(allocator);
    defer{list2.deinit();}
    try list2.append(50);
    try list2.append(1);
    try list2.append(23);
    try list2.append(8);
    try list2.append(8);
    const refl2 = getReflectionIndex(list2);
    std.debug.print("Reflection index: {d}\n", .{refl2});
    try expect(refl2==4);
}

pub fn getReflection(rows:ArrayList(u64), cols:ArrayList(u64)) u64 {
    // Find horizontal reflections in rows first
    var total_reflection:u64 = 0;
    const reflection_row = getReflectionIndex(rows);
    if (reflection_row > 0) {
        total_reflection = (reflection_row) * 100;
    }
    const reflection_col = getReflectionIndex(cols);
    if (reflection_row > 0 and reflection_col > 0) {
        std.debug.print("This grid has reflections horizontally and vertically!", .{});
    }
    if (reflection_col > 0) {
        total_reflection += reflection_col;
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
            const reflection_num = getReflection(rows, cols);
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
    
    std.debug.print("Sum of reflection numbers (part {d}): {d}\n", .{part_num, part_one_answer});
    return part_answer;
}

pub fn main() !void {
    const part_one = try solvePart(1);
    std.debug.print("Part 1: {d}", .{part_one});
    //try solvePart(2);
}
