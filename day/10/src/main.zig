const std = @import("std");

const Coord = struct {
    row: usize,
    col: usize,
    pub fn goTo(self: *Coord, other: Coord) void {
        self.row = other.row;
        self.col = other.col;
    }
    pub fn eql(self: *const Coord, other: Coord) bool {
        return self.row == other.row and self.col == other.col;
    }
};

const PipeBend = struct {
    location: Coord,
    pipe_type: u8,
    connection1: Coord,
    connection2: Coord,

    pub fn init(location:Coord, pipe_type:u8) PipeBend {
        var pipe = PipeBend {
            .location = location,
            .pipe_type = pipe_type,
            .connection1 = Coord { .row = 0, .col = 0 },
            .connection2 = Coord { .row = 0, .col = 0 },
        };
        switch (pipe_type) {
            '|' => {
                pipe.connection1 = Coord { .row = location.row - 1, .col = location.col };
                pipe.connection2 = Coord { .row = location.row + 1, .col = location.col };
            },
            '-' => {
                pipe.connection1 = Coord { .row = location.row, .col = location.col - 1 };
                pipe.connection2 = Coord { .row = location.row, .col = location.col + 1 };
            },
            'L' => {
                pipe.connection1 = Coord { .row = location.row - 1, .col = location.col };
                pipe.connection2 = Coord { .row = location.row, .col = location.col + 1 };
            },
            'J' => {
                pipe.connection1 = Coord { .row = location.row - 1, .col = location.col };
                pipe.connection2 = Coord { .row = location.row, .col = location.col - 1 };
            },
            '7' => {
                pipe.connection1 = Coord { .row = location.row, .col = location.col - 1 };
                pipe.connection2 = Coord { .row = location.row + 1, .col = location.col };
            },
            'F' => {
                pipe.connection1 = Coord { .row = location.row, .col = location.col + 1 };
                pipe.connection2 = Coord { .row = location.row + 1, .col = location.col };
            }, 
            else => {
                pipe.connection1 = Coord { .row = location.row, .col = location.col };
                pipe.connection2 = Coord { .row = location.row, .col = location.col };
            }
        }
        return pipe;
    }    
};

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



pub fn solvePartOne(buffer: []const u8, row_length:usize) usize {
    var loop_length:usize = 0;
    // First find the 'S' character which is Start
    var start: Coord = Coord { .row = 0, .col = 0 };
    var current: Coord = Coord { .row = 0, .col = 0 };
    var last: Coord = Coord{ .row = start.row, .col = start.col };
    for (buffer) |c| {
        if (c == 'S') {
            break;
        }
        start.col += 1;
        if (c == '\n') {
            start.row += 1;
            start.col = 0;
        }
    }
    std.debug.print("Found Start at row {d}, col {d}\n", .{start.row, start.col});
    // Sweep the 3x3 grid around the start to find the first pipe that has one
    // of its connectors connected to the start. Then move to that connector.
    for (start.row-1..start.row+1) |row| {
        for (start.col-1..start.col+1) |col| {
            const c = getCharacterAt(buffer, row, col, row_length);
            if (c == '|' or c == '-' or c == 'L' or c == 'J' or c == '7' or c == 'F') {
                const pipe = PipeBend.init(Coord { .row = row, .col = col }, c);
                if (pipe.connection1.eql(start)) {
                    current.goTo(pipe.connection2);
                    last.goTo(pipe.location);
                    break;
                } else if (pipe.connection2.eql(start)) {
                    current.goTo(pipe.connection1);
                    last.goTo(pipe.location);
                    break;
                }
            }
        }
    }
    // Now we can start the loop
    loop_length = 1;
    

    // Keep following pipes until we get back to Start
    while (getCharacterAt(buffer, current.row, current.col, row_length) != 'S') {
        const c = getCharacterAt(buffer, current.row, current.col, row_length);
        std.debug.print("Found pipe {c} at row {d}, col {d}\n", .{c, current.row, current.col});
        if (c == '|' or c == '-' or c == 'L' or c == 'J' or c == '7' or c == 'F') {
            const pipe = PipeBend.init(current, c);
            if (pipe.connection1.eql(last)) {
                last.goTo(current);
                current.goTo(pipe.connection2);
            } else if (pipe.connection2.eql(last)) {
                last.goTo(current);
                current.goTo(pipe.connection1);
            }
        } else {
            std.debug.print("Error! Hit an unknown pipe {c} at row {d}, col {d}\n", .{c, current.row, current.col});
        }
        loop_length += 1;
    }
    loop_length += 1; // add one to account for the last pipe
    std.debug.print("Looped back to Start at row {d}, col {d}\n", .{current.row, current.col});
    std.debug.print("Loop length is {d}\n", .{loop_length});
    return loop_length / 2;
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

    // Part 1
    const loop_length = solvePartOne(buffer, row_length);
    std.debug.print("Part 1: {d}\n", .{loop_length});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
