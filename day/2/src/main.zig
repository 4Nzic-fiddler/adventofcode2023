const std = @import("std");
const expect = std.testing.expect;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

pub fn setIsPossible(max_values:StringHashMap(u8), set:StringHashMap(u8)) bool{
    var all_values_possible:bool = true;
    var iterator = set.iterator();
    while (iterator.next()) |kv| {
        const key: []const u8 = kv.key_ptr.*;
        const value: u8 = kv.value_ptr.*;
        // if the max value for this color is not defined, we'll default to 0 so every value is too high
        const max_value: u8 = max_values.get(key).?;
        if (value > max_value) {
            std.debug.print("value: {d} > max_value: {d}\n", .{value, max_value});
            all_values_possible = false;
            break;
        }
    }
    return all_values_possible;
}

pub fn gameMinPossibleCubes(min_values:*StringHashMap(u8), sets:ArrayList([] const u8)) !void {
    for (sets.items) |set| {
        var set_values = std.StringHashMap(u8).init(std.heap.page_allocator);
        defer set_values.deinit();
        const parsed:bool = parseSet(set, &set_values) catch false;
        if (parsed) {
            var iterator = set_values.iterator();
            while (iterator.next()) |kv| {
                // This is such clunky syntax for iterating through the keys and values of a hashmap
                // but this seems to be the itomatic way to do it in Zig!
                const key: []const u8 = kv.key_ptr.*; // dereference the pointer to get the key
                const value: u8 = kv.value_ptr.*; // dereference the pointer to get the value
                // You know, getOrPut should take two values, the key and the value to put if the key
                // doesn't exist. But it doesn't. So we have to do this, using .found_existing.
                var min_value = try min_values.getOrPut(key);
                if (!min_value.found_existing) {
                    min_value.value_ptr.* = value;
                } else if (value > min_value.value_ptr.*) {
                    try min_values.put(key, value);
                }
                
            }
        }
    }
}

/// Takes a list of sets and returns the power of the minimum cubes needed to make the game possible
/// This is only used for part two
pub fn getGamePower(sets:ArrayList([] const u8)) !u32 {
    var min_values = std.StringHashMap(u8).init(std.heap.page_allocator);
    defer min_values.deinit();
    try gameMinPossibleCubes(&min_values, sets);
    var power:u32 = 0;
    var iterator = min_values.valueIterator();
    while (iterator.next()) |value| {
        if (power==0) {
            power = value.*;
        } else {
            power *= value.*;
        }
    }
    return power;
}

/// Returns true if the given game is possible given the max values of each color
/// This is only used for part one
pub fn gameIsPossible(max_values:StringHashMap(u8), sets:ArrayList([] const u8)) bool {
    var all_sets_possible:bool = true;
    for (sets.items) |set| {
        var set_values = std.StringHashMap(u8).init(std.heap.page_allocator);
        defer set_values.deinit();
        const parsed:bool = parseSet(set, &set_values) catch false;
        if (parsed and setIsPossible(max_values, set_values)) {
            continue;
        } else {
            all_sets_possible = false;
            break;
        }
    }
    return all_sets_possible;
}

/// Takes a set string and a StringHashMap of values. Adds the colors (keys) and numbers (values) to the values map.
pub fn parseSet(set_string:[]const u8, values:*StringHashMap(u8)) !bool {
    var set_iterator = std.mem.split(u8, set_string, ",");
    while (set_iterator.next()) |token| {
        var token_string = std.mem.trim(u8, token, " ");
        var token_iterator = std.mem.split(u8, token_string, " ");
        if (token_iterator.next()) |value| {
            var value_int = std.fmt.parseInt(u8, value, 10) catch 0;
            if (token_iterator.next()) |color| {
                try values.put(color, value_int);
            }
        }
    }
    return true;
}

/// takes a line and an allocated ArrayList. Returns the game number or 0 if the line didn't match
/// the expected format. Adds the sets, if any, as unparsed strings to the sets ArrayList.
/// It is the caller's responsibility to parse and then deinit the sets ArrayList.
pub fn parseLine(line:[]const u8, sets: *ArrayList([] const u8)) !u32 {
    var game_num:u32 = 0;
    // Split line by ':' to get "Game #" and the rest of the line
    var token_iterator = std.mem.split(u8, line, ":");
    if (token_iterator.next()) |token| {
        var game_token = std.mem.trim(u8, token, " ");
        // Now split the Game string from the number
        var game_num_iterator = std.mem.split(u8, game_token, " ");
        if (game_num_iterator.next()) |game| {
            // Verify that the first token is "Game" otherwise this line is malformed
            if (std.mem.eql(u8, game, "Game")) {
                // Now we have the game number, parse it
                if (game_num_iterator.next()) |game_num_str| { 
                    game_num = std.fmt.parseInt(u32, game_num_str, 10) catch 0;
                }
                
            }
        }
    }
    // Now parse the rest of the line
    if (token_iterator.next()) |token| {
        var set_iterator = std.mem.split(u8, token, ";");
        while (set_iterator.next()) |set| {
            const set_string = std.mem.trim(u8, set, " ");
            try sets.append(set_string);
        }
    }
    return game_num;
}

/// Takes a line specifying a game, grabs the game number and figures out if the game is
/// possible given the max values of each color. If it is, adds the game number to the sum
/// This is only used for part one
pub fn addToSumIfPossible(line: []const u8, sum_of_possible: u32, max_values: StringHashMap(u8)) u32 {
    var sets = std.ArrayList([]const u8).init(std.heap.page_allocator);
    defer sets.deinit();
    const game_num:u32 = parseLine(line, &sets) catch 0;
    // If all sets from this game are possible, add the game number to the sum
    if (gameIsPossible(max_values, sets)) {
        std.debug.print("game {d} is possible\n", .{game_num});
        return sum_of_possible + game_num;
    }
    else {
        std.debug.print("game {d} is not possible\n", .{game_num});
    }
    // Otherwise, return the sum unchanged
    return sum_of_possible;
}

/// Takes a line specifying a game, ignores the game number, returns the power of the minimum cubes needed
/// to make this game possible. This is only used in part two
pub fn addPowerToSum(line: []const u8, sum_of_powers: u32) !u32 {
    var sets = std.ArrayList([]const u8).init(std.heap.page_allocator);
    defer sets.deinit();
    const game_num:u32 = parseLine(line, &sets) catch 0;
    // If we parsed sets, calculate the power and add it to the sum
    // Note: you'd expect to get the length of sets with sets.len, but NOPE!
    // you have to use sets.items.len. okaaaaaay.
    if (sets.items.len > 0) {
        var power:u32 = try getGamePower(sets);
        std.debug.print("game {d} power is {d}\n", .{game_num, power});
        return sum_of_powers + power;
    }
    else {
        std.debug.print("game {d} has no sets\n", .{game_num});
    }
    // Otherwise, return the sum unchanged
    return sum_of_powers;
}

pub fn solvePartOne() !u32 {
    var sum_of_possible:u32 = 0;
    // Open input file and schedule closing it at the end of this block
    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    // Given constraints of max values of each color, create a hashmap of those values
    const allocator = std.heap.page_allocator;
    var max_values = std.StringHashMap(u8).init(allocator);
    defer max_values.deinit();
    try max_values.put("red", 12);
    try max_values.put("green", 13);
    try max_values.put("blue", 14);


    // Create a 4k buffer to read lines into
    var buf: [4096]u8 = undefined;

    // Read lines from stdin until EOF is reached. Lines are delimited by '\n'
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len > 0) {
            // DEBUG: Print the line for manual review
            std.debug.print("line: {s}\n", .{line});
            sum_of_possible = addToSumIfPossible(line, sum_of_possible, max_values);
        }
    }
    return sum_of_possible;
}

pub fn solvePartTwo() !u32 {
    var sum_of_powers:u32 = 0;
    // Open input file and schedule closing it at the end of this block
    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    // Create a 4k buffer to read lines into
    var buf: [4096]u8 = undefined;

    // Read lines from stdin until EOF is reached. Lines are delimited by '\n'
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len > 0) {
            // DEBUG: Print the line for manual review
            std.debug.print("line: {s}\n", .{line});
            sum_of_powers = addPowerToSum(line, sum_of_powers) catch sum_of_powers;
        }
    }
    return sum_of_powers;
}

pub fn main() !void {
    // Part One
    const answerOne:u32 = try solvePartOne();
    std.debug.print("Part One Answer: {d}\n", .{answerOne});
    // Part Two
    const answerTwo:u32 = try solvePartTwo();
    std.debug.print("Part Two Answer: {d}\n", .{answerTwo});
}

test "example input produces 8" {
    const input = 
    \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
    \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
    \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
    \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
    \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;
    const allocator = std.heap.page_allocator;
    var max_values = std.StringHashMap(u8).init(allocator);
    defer max_values.deinit();
    try max_values.put("red", 12);
    try max_values.put("green", 13);
    try max_values.put("blue", 14);

    var sumOfPossible:u32 = 0;
    var iterator = std.mem.split(u8, input, "\n");
    while (iterator.next()) |line| {
        std.debug.print("line: {s}\n", .{line});
        sumOfPossible = addToSumIfPossible(line, sumOfPossible, max_values);
    }
    try expect(sumOfPossible == 8);
}
