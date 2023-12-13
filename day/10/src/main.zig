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



pub fn solveBothParts(buffer: []const u8, row_length:usize) !void {
    var loop_length:usize = 0;
    const allocator = std.heap.page_allocator;
    // Create an array of bools to keep track of which pipes are part of the loop
    var loop_pipes = try allocator.alloc(bool, buffer.len);
    defer allocator.free(loop_pipes);
    // Initialize loop_pipes to false
    @memset(loop_pipes, false); 

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
    // Set start as part of the loop
    loop_pipes[start.row * (row_length+1) + start.col] = true;
    // Sweep the 3x3 grid around the start to find the first pipe that has one
    // of its connectors connected to the start. Then move to that connector.
    for (start.row-1..start.row+2) |row| {
        for (start.col-1..start.col+2) |col| {
            const c = getCharacterAt(buffer, row, col, row_length);
            if (c == '|' or c == '-' or c == 'L' or c == 'J' or c == '7' or c == 'F') {
                const pipe = PipeBend.init(Coord { .row = row, .col = col }, c);
                if (pipe.connection1.eql(start)) {
                    std.debug.print("Found pipe connected to start {c} at row {d}, col {d}\n", .{c, pipe.connection2.row, pipe.connection2.col});
                    current.goTo(pipe.connection2);
                    last.goTo(pipe.location);
                    break;
                } else if (pipe.connection2.eql(start)) {
                    std.debug.print("Found pipe connected to start {c} at row {d}, col {d}\n", .{c, pipe.connection2.row, pipe.connection2.col});
                    current.goTo(pipe.connection1);
                    last.goTo(pipe.location);
                    break;
                }
            }
        }
    }
    // Mark the first pipe connected to start as part of the loop, since we skipped over it
    loop_pipes[last.row * (row_length+1) + last.col] = true;
    // Now we can start the loop
    loop_length = 2; // we start at 2 because we've already found the start and the first pipe connected to it
    

    // Keep following pipes until we get back to Start
    while (getCharacterAt(buffer, current.row, current.col, row_length) != 'S') {
        const c = getCharacterAt(buffer, current.row, current.col, row_length);
        //std.debug.print("Found pipe {c} at row {d}, col {d}\n", .{c, current.row, current.col});
        if (c == '|' or c == '-' or c == 'L' or c == 'J' or c == '7' or c == 'F') {
            const pipe = PipeBend.init(current, c);
            // Set the current pipe as part of the loop
            loop_pipes[current.row * (row_length+1) + current.col] = true;
            if (pipe.connection1.eql(last)) {
                last.goTo(current);
                current.goTo(pipe.connection2);
            } else if (pipe.connection2.eql(last)) {
                last.goTo(current);
                current.goTo(pipe.connection1);
            }
        } else {
            std.debug.print("Error! Hit an unknown pipe {c} at row {d}, col {d}\n", .{c, current.row, current.col});
            break;
        }
        loop_length += 1;
    }
    loop_pipes[last.row * (row_length+1) + last.col] = true; // set the last pipe as part of the loop
    std.debug.print("Looped back to Start at row {d}, col {d}\n", .{current.row, current.col});
    std.debug.print("Last pipe is {c} at row {d}, col {d}\n", .{getCharacterAt(buffer, last.row, last.col, row_length), last.row, last.col});
    std.debug.print("Loop length is {d}\n", .{loop_length});
    std.debug.print("Part 1 solution (loop length / 2) is {d}\n", .{loop_length / 2});

    // Part two: find the non-loop grid cells that are enclosed by the loop
    // Strategy: Go left to right for each row. Look for pipe crossings.
    // If we find | that's a full crossing. If we find a 90 degree bend, that's HALF a crossing.
    // A half crossing can only become a full crossing if the next 90 degree bend goes the other way.
    // That is, F--J is a full crossing, and L--7 is a full crossing, (with 0 or more - between) because
    // one pipe goes north and the other pipe goes south (so together they are like a | pipe)!
    // If we find a full crossing, we can start counting enclosed cells until we find the next full crossing.
    var area_inside_loop:usize = 0;
    var current_half_crossing:u8 = '.';
    var inside_loop:bool = false;
    current.row = 0;
    current.col = 0;
    for (buffer) |c| {
        const part_of_loop:bool = loop_pipes[current.row * (row_length+1) + current.col];
        if (part_of_loop) {
            var pipe_type:u8 = c;
            if (c == 'S') { // we care about what pipe type the start actually is
                pipe_type = inferPipeTypeOfStart(buffer, row_length, current);
                std.debug.print("Inferred pipe type of start is {c}\n", .{pipe_type});
            }
            if (pipe_type == '|') {
                inside_loop = !inside_loop; // full crossing, toggle inside/outside
                //std.debug.print("Found | at row {d}, col {d}, inside_loop={any}\n", .{current.row, current.col, inside_loop});
            } else if (pipe_type == 'F' or pipe_type == 'L') { // start of half crossing!
                current_half_crossing = pipe_type; // reset
            } else if (pipe_type == 'J' or pipe_type == '7') { // end of half crossing!
                if (current_half_crossing == 'F' and pipe_type == 'J') {
                    inside_loop = !inside_loop; // full crossing, toggle inside/outside
                    current_half_crossing = '.';
                } else if (current_half_crossing == 'L' and pipe_type == '7') {
                    inside_loop = !inside_loop; // full crossing, toggle inside/outside
                    current_half_crossing = '.'; // reset
                } else {
                    // not a full crossing, reset
                    current_half_crossing = '.';
                }
            } else if (pipe_type == '-') {
                if (current_half_crossing != 'F' and current_half_crossing != 'L') {
                    // Note unexpected condition: we found a - pipe but we didn't find a half crossing before it
                    std.debug.print("Found unexpected - pipe at row {d}, col {d}\n", .{current.row, current.col});
                }
            }
        } else {
            // If this cell is not part of the loop, then count it as part of the area
            // if we're inside the loop only
            if (inside_loop) {
                area_inside_loop += 1;
                //std.debug.print("Found area inside loop at row {d}, col {d}\n", .{current.row, current.col});
            }
        }
        
        current.col += 1;
        if (c == '\n') {
            current.row += 1;
            current.col = 0;
            inside_loop = false; // have to reset inside_loop for each row
        }
    }
    
    std.debug.print("Part 2 solution (area inside loop) is {d}\n", .{area_inside_loop});
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

    // Part 1 and 2
    try solveBothParts(buffer, row_length);
    
}

pub fn inferPipeTypeOfStart(buffer: []const u8, row_length:usize, start_coord:Coord) u8 {
    // Sweep around the 3x3 grid around the start to find 
    // both pipes that are connected to the start, then we
    // can infer the type of the start pipe
    var connected_pipes: [2]PipeBend = undefined;
    var found_connections: u8 = 0;
    for (start_coord.row-1..start_coord.row+1) |row| {
        for (start_coord.col-1..start_coord.col+1) |col| {
            const c = getCharacterAt(buffer, row, col, row_length);
            if (c == '|' or c == '-' or c == 'L' or c == 'J' or c == '7' or c == 'F') {
                const pipe = PipeBend.init(Coord { .row = row, .col = col }, c);
                if (pipe.connection1.eql(start_coord) or pipe.connection2.eql(start_coord)) {
                    connected_pipes[found_connections] = PipeBend.init(Coord { .row = row, .col = col }, c);
                    found_connections += 1;
                    if (found_connections == 2) {
                        break;
                    }
                }
            }
        }
        if (found_connections == 2) {
            break;
        }
    }
    // Now we can infer the type of the start pipe
    // Note that connected_pipes[0] will be never be below start_coord
    // and then  connected_pipes[1] will be never be above start_coord
    // Therefore, connected_pipes[0].pipe_type will never be 'J'
    // and connected_pipes[1].pipe_type will never be 'F'
    if (connected_pipes[0].location.row < start_coord.row) { // connected_pipes[0] is above start_coord
        if (connected_pipes[1].location.row == start_coord.row) { // connected_pipes[1] is left or right
            if (connected_pipes[1].location.col < start_coord.col) { // connected_pipes[1] is to the left of start_coord
                return 'J';
            } else { // connected_pipes[1] is to the right of start_coord
                return 'L';
            }
        } else { // connected_pipes[1] is below start_coord
            return '|';
        }
    } else { // connected_pipes[0] is left or right of start_coord
        if (connected_pipes[1].location.row == start_coord.row) { // connected_pipes[1] is right, so connected_pipes[0] must be left
            return '-';   
        } else { // connected_pipes[1] is below, so figure out if connected_pipes[0] is left or right
            if (connected_pipes[0].location.col < start_coord.col) { // connected_pipes[0] is to the left of start_coord
                return '7';
            } else { // connected_pipes[0] is to the right of start_coord
                return 'F';
            }
        }
    }
    return '.'; // this is an error and indicates an invalid pipe map where start is not properly connected to a loop
}
