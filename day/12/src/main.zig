const std = @import("std");
const ArrayList = std.ArrayList;
const testing = std.testing;
const expect = testing.expect;

pub fn canFitAt(spring_map:[]const u8, start:usize, length:usize) bool {
    var can_fit:bool = true;
    for (start..(start+length)) |i| {
        // Can't fit if we would go past the end of the map
        if (i >= spring_map.len) {
            can_fit = false;
            break;
        }
        // Can't fit if there's a known blank space in the middle
        if (spring_map[i] == '.') {
            can_fit = false;
            break;
        }
    }
    // Also can't fit if there's a known spring before the beginning without a space between
    if (can_fit and start > 0) {
        if (spring_map[start-1] == '#') {
            can_fit = false;
        }
    }
    // Also can't fit if there's a known spring after the end without a space between
    if (can_fit and start+length < spring_map.len) {
        if (spring_map[start+length] == '#') {
            can_fit = false;
        }
    }
    return can_fit;
}

/// returns the index of the rightmost # symbol in the map, or 0 if no # exist in map
pub fn positionOfLastHash(spring_map:[]const u8) usize {
    var i:usize = spring_map.len;
    while (i>0) {
        i -= 1;
        if (spring_map[i]=='#') {
            break;
        }
    }
    return i;
}

/// returns the index of the leftmost # symbol in the map, or map length if no # exist in map
pub fn positionOfFirstHash(spring_map:[]const u8) usize {
    var i:usize = 0;
    while (i < spring_map.len) {
        if (spring_map[i]=='#') {
            break;
        }
        i += 1;
    }
    return i;
}

/// given the index of a spring, figure out the lowest placement in the map possible while making room for other springs to the left
pub fn getLowestPossibleStart(spring_map:[]const u8, spring_lengths:ArrayList(u8), spring_num:usize, prev_lowest_placement_right:usize) usize {
    // First sum up the minimum space required by all springs to the LEFT (lower indices)
    // For the first spring, there are no springs to the left, but there could be impossible placements
    var lowest_placement:usize = prev_lowest_placement_right;
    // Note: I first came up with a recursive way to do this right to left that was beautiful, 
    // but iterating left to right and caching the previous answer is smarter and faster
    while (!canFitAt(spring_map, lowest_placement, spring_lengths.items[spring_num])) {
        lowest_placement += 1;
    }
    // One special case: if this is the LAST spring in our list, then it MUST cover the last #
    if (spring_num == spring_lengths.items.len-1) {
        const last_hash_pos = positionOfLastHash(spring_map);
        // the last hash COULD be close to the start of the map, so make sure we don't go below 0
        var placement_to_cover_last_hash = last_hash_pos;
        if (last_hash_pos > (spring_lengths.items[spring_num] - 1)) {
            placement_to_cover_last_hash -= (spring_lengths.items[spring_num] - 1);
        } else {
            placement_to_cover_last_hash = 0;
        }
        if (placement_to_cover_last_hash > lowest_placement) {
            lowest_placement = placement_to_cover_last_hash;
        }
    }
    return lowest_placement; 
}
test "Check lowest possible start" {
    var numbers1 = std.ArrayList(u8).init(std.testing.allocator);
    defer numbers1.deinit();
    try numbers1.append(1);
    try numbers1.append(3);
    try numbers1.append(2);
    try expect(getLowestPossibleStart("#.???.??#", numbers1, 0, 0) == 0);
    try expect(getLowestPossibleStart("#?????#????.#?#", numbers1, 1, 1) == 2);
    try expect(getLowestPossibleStart("..???..#????????#.??????", numbers1, 0, 0) == 2);
    try expect(getLowestPossibleStart("..???..#????????#.??????", numbers1, 1, 3) == 7);
}

/// given the index of a spring, figure out the highest placement in the map possible while making room for other springs to the right
pub fn getHighestPossibleStart(spring_map:[]const u8, spring_lengths:ArrayList(u8), spring_num:usize, where_to_start_looking:usize) usize {
    var highest_placement:usize = where_to_start_looking;
    while (!canFitAt(spring_map, highest_placement, spring_lengths.items[spring_num])) {
        highest_placement -= 1;
    }
    // One special case: if this is the FIRST spring in our list, then it MUST cover the first #
    if (spring_num == 0) {
        const first_hash_pos = positionOfFirstHash(spring_map);
        // the rightmost placement that covers the hash is at the hash position 
        if (first_hash_pos < highest_placement) {
            highest_placement = first_hash_pos;
        }
    }
    return highest_placement;
}
test "Check highest possible start" {
    var numbers1 = std.ArrayList(u8).init(std.testing.allocator);
    defer numbers1.deinit();
    try numbers1.append(1);
    try numbers1.append(3);
    try numbers1.append(2);
    try expect(getHighestPossibleStart("#.???.??#", numbers1, 0, 0) == 0);
    try expect(getHighestPossibleStart("#?????.????.#???#", numbers1, 2, 16) == 15);
    try expect(getHighestPossibleStart("#?????.????.#???#", numbers1, 1, 11) == 8);
}

pub fn springBetweenSprings(spring_map:[]const u8, left_spring_end:usize, right_spring_start:usize) bool {
    for (left_spring_end..right_spring_start) |i| {
        if (spring_map[i] == '#') {
            return true;
        }
    }
    return false;
}

// This is an example of a very complex map to process, with a lot of 1s and a lot of ? and lots of overlapping possibilities
// ?.??????#?????#???????.??????#?????#???????.??????#?????#???????.??????#?????#???????.??????#?????#????? 1,6,1,1,1,1,1,6,1,1,1,1,1,6,1,1,1,1,1,6,1,1,1,1,1,6,1,1,1,1,
// map is 104 characters, and numbers takes a minimum of 84 characters - probably no help
// It will take way too long to find all the arrangements using numPossibleArrangements() function
// So let's try a different approach, starting at the right and working back caching results
pub fn fasterArrangements(spring_map:[]const u8, spring_lengths:ArrayList(u8)) !u64 {
    var num_arrangements:u64 = 0; // keep track of our final answer as we go
    const allocator = std.heap.page_allocator;
    // Cache the lowest possible starting positions for each spring, going left to right
    var lowest_possible_starts = ArrayList(usize).init(allocator);
    var left_side:usize = 0;
    var right_side:usize = 0;
    for (0..spring_lengths.items.len) |i| {
        left_side = getLowestPossibleStart(spring_map, spring_lengths, i, right_side);
        right_side = left_side + spring_lengths.items[i] + 1; // account for spring length and pad
        try lowest_possible_starts.append(left_side); // cache result so we don't recompute == speedup!
        //std.debug.print("lowest possible start of spring {d} is {d}\n", .{i, left_side});
    }
    
    // Also cache the highest possible starting positions for each spring, going right to left
    var highest_possible_starts = try lowest_possible_starts.clone(); // allocate same length of list
    var spring_num:usize = spring_lengths.items.len; // we start at the END of the spring list
    var highest_start:usize = spring_map.len;
    while (spring_num > 0) {
        spring_num -= 1; // weird, but this is the standard zig pattern for looping backwards ¯\_(ツ)_/¯
        highest_start = highest_start - spring_lengths.items[spring_num]; // account for current spring length
        highest_start = getHighestPossibleStart(spring_map, spring_lengths, spring_num, highest_start);
        highest_possible_starts.items[spring_num] = highest_start;
        //std.debug.print("highest possible start of spring {d} is {d}\n", .{spring_num, highest_start});
        if (highest_start>0) {
            highest_start -= 1; // account for pad
        } 
    }

    // We need to cache the number of possible combinations per starting spot on the map
    // for the current spring we're trying to place. For the last spring in the list,
    // the value will be 1 for each possible starting place. 
    // For every other spring, working from back to front of spring_lengths, the value
    // will be the sum of all the other values in this hashmap for keys that are
    // greater than one more than the right end of the current spring placement.
    var results_cache_current = try allocator.alloc(u64, spring_map.len); // cached results for next iteration
    var results_cache_last = try allocator.alloc(u64, spring_map.len); // used to calculate current cache
    for (0..spring_map.len) |i| {
        results_cache_current[i] = 0;
        results_cache_last[i] = 0;
    }
    // Go right to left through the springs
    spring_num = spring_lengths.items.len;
    while (spring_num > 0) {
        spring_num -= 1;
        //std.debug.print("fasterArrangements checking spring {d}\n", .{spring_num});
        var result_for_this_spring:usize = 0;
        var low_end:usize = lowest_possible_starts.items[spring_num]; // use cached value for SPEED!
        var high_end:usize = highest_possible_starts.items[spring_num]; // SPEED... I am SPEED!
        //std.debug.print("Spring {d} can go from {d} to {d}\n", .{spring_num, low_end, high_end});
        for (low_end..high_end+1) |i| {
            // first check if we can even place the spring here
            if (canFitAt(spring_map, i, spring_lengths.items[spring_num])) {
                //std.debug.print("Spring {d} can fit at {d} :: ", .{spring_num, i});
                // if it can fit, find the spring right side position (this accounts for the 1 padding, too!)
                var current_spring_right = i+spring_lengths.items[spring_num]; 
                // now, here's the huge speed boost for the win: we can sum the
                // number of combos for every possible placement of the spring
                // to the right that are HIGHER than right_plus_pad and that
                // is the number of combos for THIS spot! 
                var combos_for_this_spot:usize = 0;
                if (spring_num == spring_lengths.items.len-1) {
                    combos_for_this_spot = 1; // special case for right most spring
                } else {
                    var sum_of_prev:usize = 0;
                    for (current_spring_right+1..spring_map.len) |j| {
                        // check for any fixed spring spots between springs
                        // and only count this arrangement if there aren't any "extras"
                        if (!springBetweenSprings(spring_map, current_spring_right, j)) {
                            sum_of_prev += results_cache_last[j];
                        }
                        
                    }
                    combos_for_this_spot = sum_of_prev;
                }
                result_for_this_spring += combos_for_this_spot;
                //std.debug.print("Added {d} to result for this spring, sum is now {d}\n", .{combos_for_this_spot, result_for_this_spring});
                results_cache_current[i] = combos_for_this_spot;
            }
        }
        // Done going through the possible placements for this spring, move current cache to prev cache
        for (0..spring_map.len) |i| {
            results_cache_last[i] = results_cache_current[i];
            results_cache_current[i] = 0;
        } 
        // the total number of arrangements is equal to the result for spring 0
        num_arrangements = result_for_this_spring;
    }
    // Return the final sum
    return num_arrangements;
}
test "faster arrangements" {
    // Line: .?.??##?????..? 5,2, Possible arrangements: 3
    std.debug.print("\nLine: .?.??##?????..? 5,2, Possible arrangements: 3\n", .{});
    var numbers1 = std.ArrayList(u8).init(std.testing.allocator);
    defer numbers1.deinit();
    try numbers1.append(5);
    try numbers1.append(2);
    var result = try fasterArrangements(".?.??##?????..?", numbers1);
    std.debug.print("Result is {d}\n", .{result});
    try expect(result == 3);

    // Line: ?????#?#?.#???.?? 1,3,4, Possible arrangements: 4
    std.debug.print("\nLine: ?????#?#?.#???.?? 1,3,4, Possible arrangements: 4\n", .{});
    var numbers2 = std.ArrayList(u8).init(std.testing.allocator);
    defer numbers2.deinit();
    try numbers2.append(1);
    try numbers2.append(3);
    try numbers2.append(4);
    result = try fasterArrangements("?????#?#?.#???.??", numbers2);
    std.debug.print("Result is {d}\n", .{result});
    try expect(result == 4);
}

pub fn numPossibleArrangements(spring_map:[]const u8, numbers:ArrayList(u8), map_start:usize, numbers_start:usize) u64 {
    var num_arrangements:u64 = 0;
    var current_number:u8 = numbers.items[numbers_start];
    // Find each ? in the spring_map starting at map_start
    // and check to see if current_number of springs could fit there
    if (numbers_start < numbers.items.len and map_start < spring_map.len) {
        for (map_start..spring_map.len) |i| {
            var num_arrangements_for_this_start:u64 = 0;
            //std.debug.print("Checking {d} for fit of {d}...\n", .{i, current_number});
            if (spring_map[i] != '.' and canFitAt(spring_map, i, current_number)) {
                //std.debug.print("canFitAt(spring_map, {d}, {d}) is true\n", .{i, current_number});
                // If this was the last number, then we need to check to the end of the map
                if (numbers_start == numbers.items.len-1) {
                    var no_more_springs_to_end:bool = true;
                    var j:usize = i+current_number;
                    while (j < spring_map.len) {
                        if (spring_map[j] == '#') {
                            no_more_springs_to_end = false;
                            break;
                        }
                        j += 1;
                    }
                    if (no_more_springs_to_end) {
                        // If we placed the last number and there were no more springs to the end,
                        // then this is a valid arrangement
                        num_arrangements_for_this_start += 1;
                    } 
                } else {
                    // Otherwise, we need to find out if it is possible to fit the next number(s)
                    var other_arrangements = numPossibleArrangements(spring_map, numbers, i+current_number+1, numbers_start+1);
                    if (other_arrangements > 0) {
                        num_arrangements_for_this_start += other_arrangements;
                    } else {
                        // If it's not possible to fit the next number(s), then this arrangement is invalid, too
                        num_arrangements_for_this_start = 0;
                    }
                }
            }
            num_arrangements += num_arrangements_for_this_start;
            // If we just placed this number at a #, then it cannot also be placed to the right
            // of this #, so we can skip ahead to the next number
            if (spring_map[i] == '#') {
                break;
            }
        }
    }
    return num_arrangements;
}
test "Check number of possible arrangements" {
    var numbers1 = std.ArrayList(u8).init(std.testing.allocator);
    defer numbers1.deinit();
    try numbers1.append(1);
    try numbers1.append(2);
    try numbers1.append(3);
    try expect(numPossibleArrangements("#.???.#?#", numbers1, 0, 0) == 2);
    try expect(numPossibleArrangements("#?????#????.#?#", numbers1, 0, 0) == 2);
    var numbers2 = std.ArrayList(u8).init(std.testing.allocator);
    defer numbers2.deinit();
    for (0..5) |i| { // 4,2,4,2,4,2,4,2,4,2
        _ = i;
        try numbers2.append(4);
        try numbers2.append(2);
    }
    try expect(numPossibleArrangements("?.????#?.??????.????#?.??????.????#?.??????.????#?.??????.????#?.????", numbers2, 0,0) == 60000);
}

pub fn solvePart(part_num:u8) !u64 {
    // Now we handle both part 1 and 2 according to part_num
    const allocator = std.heap.page_allocator;
    var total_arrangements:u64 = 0;
    // Open input file and schedule closing it at the end of this block
    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    // Create a 4k buffer to read lines into
    var buf: [4096]u8 = undefined;

    // Read lines from stdin until EOF is reached. Lines are delimited by '\n'
    // Each line consists of a map of ?.# then space and a list of comma-separated numbers
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var trimmed_line = std.mem.trim(u8, line, " ");
        var parts_iterator = std.mem.split(u8, trimmed_line, " ");
        if (parts_iterator.next()) |spring_map|{
            //std.debug.print("Spring map: {s} ", .{spring_map});
            if (parts_iterator.next()) |numbers|{
                //std.debug.print("Numbers: {s}\n", .{numbers});
                var numbers_iterator = std.mem.split(u8, numbers, ",");
                var numbers_list = std.ArrayList(u8).init(allocator);
                while (numbers_iterator.next()) |number_str| {
                    var number:u8 = try std.fmt.parseInt(u8, number_str, 10);
                    try numbers_list.append(number);
                }
                // Now we have a map of spring conditions with unknowns represented by ?
                // and an arraylist of numbers of contiguous springs, so let's use a
                // recursive function to find all possible arrangements of springs 
                // that satisfy the arraylist of numbers
                if (part_num == 1) {
                    const possible_arrangements = numPossibleArrangements(spring_map, numbers_list, 0, 0);
                    std.debug.print("Line: {s}, Possible arrangements: {d}\n", .{trimmed_line, possible_arrangements});
                    const faster_arrangements = try fasterArrangements(spring_map, numbers_list);
                    std.debug.print("Line: {s}, Faster arrangements  : {d}\n", .{trimmed_line, faster_arrangements});
                    total_arrangements += possible_arrangements;
                    try expect(possible_arrangements == faster_arrangements);
                } else if (part_num == 2) {
                    std.debug.print("Unfolding line: {s}...\n", .{trimmed_line});
                    // Replace map and number list with 5 copies of each (putting ? between copies in spring map)
                    var big_spring_map = try allocator.alloc(u8, spring_map.len*5 + 4);
                    defer allocator.free(big_spring_map);
                    //std.debug.print("Allocated {d} bytes for big_spring_map\n", .{spring_map.len*5+4});
                    var big_numbers_list = std.ArrayList(u8).init(allocator);
                    for (0..5) |i| {
                        // Copy spring_map 5 times and put ? between copies
                        const dest_start = i*(spring_map.len+1);
                        const dest_end = dest_start+spring_map.len;
                        //std.debug.print("Copying unfolded map to big_spring_map[{d}..{d}]\n", .{dest_start, dest_end});
                        std.mem.copy(u8, big_spring_map[dest_start..dest_end], spring_map[0..spring_map.len]); // type, dest, source
                        if (i < 4) {
                            big_spring_map[dest_end] = '?';
                        }
                        // Append to numbers_list 5 times
                        try big_numbers_list.appendSlice(numbers_list.items);
                    }
                    std.debug.print("Unfolded Line: {s} ", .{big_spring_map});
                    for (big_numbers_list.items) |n| {
                        std.debug.print("{d},", .{n});
                    } 
                    std.debug.print("\n", .{});
                    const faster_arrangements = try fasterArrangements(big_spring_map, big_numbers_list);
                    std.debug.print(" Faster arrangements  : {d}\n", .{faster_arrangements});
                    // now we don't need the slow way!
                    //const possible_arrangements = numPossibleArrangements(big_spring_map, big_numbers_list, 0, 0);
                    //std.debug.print(" Possible arrangements: {d}\n", .{possible_arrangements});
                    total_arrangements += faster_arrangements;
                    //try expect(faster_arrangements==possible_arrangements);
                }
                
            }
        }   
    }
    return total_arrangements;
}

pub fn main() !void {
    const part_one_answer = try solvePart(1);
    std.debug.print("Part one answer: {d}\n", .{part_one_answer});

    const part_two_answer = try solvePart(2);
    std.debug.print("Part two answer: {d}\n", .{part_two_answer});
}