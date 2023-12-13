const std = @import("std");

const Galaxy = struct {
    row: usize,
    col: usize,

    pub fn distance(self: Galaxy, other: Galaxy) usize {
        // @abs would be easier but only if we had a signed integer type. usize is unsigned
        const dist_horiz = if (self.col > other.col) self.col - other.col else other.col - self.col;
        const dist_vert = if (self.row > other.row) self.row - other.row else other.row - self.row;
        return dist_horiz + dist_vert;
    }
};

pub fn expandUniverse(galaxies: *std.ArrayList(Galaxy), empty_cols:std.ArrayList(bool), empty_rows:std.ArrayList(bool)) void {
    // Let's go BACKWARDS through the list of empty cols and empty rows
    // and move galaxies to the right and down as the empty cols and rows expand
    var row:usize = empty_rows.items.len - 2;
    while (row >= 0) {
        if (empty_rows.items[row]) {
            // Move all galaxies below row down one
            for (0..galaxies.items.len) |i| {
                var galaxy_ptr = &galaxies.items[i];
                if (galaxy_ptr.row > row) {
                    galaxy_ptr.row += 1;
                }
            }
        }
        if (row == 0) break;
        row -= 1;
    }
    var col:usize = empty_cols.items.len - 2;
    while (col >= 0) {
        if (empty_cols.items[col]) {
            // Move all galaxies to the right of col right one
            for (0..galaxies.items.len) |i| {
                var galaxy_ptr = &galaxies.items[i];
                if (galaxy_ptr.col > col) {
                    galaxy_ptr.col += 1;
                }
            }
        }
        if (col == 0) break;
        col -= 1;
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var empty_rows = std.ArrayList(bool).init(allocator);
    var empty_cols = std.ArrayList(bool).init(allocator);
    var galaxies = std.ArrayList(Galaxy).init(allocator);
    // Open input file and schedule closing it at the end of this block
    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    // Create a 4k buffer to read lines into
    var buf: [4096]u8 = undefined;

    // Read each line and find the positions of galaxies. Also keep track of 
    // which rows and which columns have no galaxies in them
    // Read lines from stdin until EOF is reached. Lines are delimited by '\n'
    // Each line consists of . for empty space and # for a galaxy, with no whitespace
    var row:usize = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var trimmed_line = std.mem.trim(u8, line, " ");
        // If we haven't initialized empty cols yet, do so now
        if (empty_cols.items.len == 0) {
            // Add a True value for each column, same length as the first line
            for (trimmed_line) |char| {
                _ = char;
                try empty_cols.append(true);
            }
        }
        // Add a True value for this row
        try empty_rows.append(true); // we'll set it to false if we find any galaxies in this row
        var col:usize = 0;
        for (trimmed_line) |char| {
            if (char=='#') {
                std.debug.print("Found galaxy at row: {d}, col: {d}\n", .{row, col});
                try galaxies.append(Galaxy{ .row = row, .col = col });
                empty_rows.items[row] = false;
                empty_cols.items[col] = false;
            } else if (char!='.') {
                std.debug.print("Found invalid character: {c} at {d}, {d}\n", .{char, row, col});
            }
            col += 1;
        }
        row += 1;
    }
    
    // Expand the universe by moving galaxies to the right and down as needed
    expandUniverse(&galaxies, empty_cols, empty_rows);

    // Part 1: Get the distance from each galaxy to every other galaxy
    // but only count the distance once (i.e. don't count the distance from A to B and B to A)
    var total_distance:usize = 0;
    for (0..galaxies.items.len) |i| {
        var galaxy = galaxies.items[i];
        for (i+1..galaxies.items.len) |j| {
            var other = galaxies.items[j];
            total_distance += galaxy.distance(other);
        }
    }
    std.debug.print("Total distance: {d}\n", .{total_distance});
}
