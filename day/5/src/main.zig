const std = @import("std");
const ArrayList = std.ArrayList;
const expect = std.testing.expect;


// Conversion holds the information needed to convert a source
// number to a destination number. It is used by ConversionSet
// which holds all the conversions for a given source and destination
const Conversion = struct{
    dest_start: u64,
    source_start: u64,
    length: u64,

    pub fn inRange(self:Conversion, source:u64) bool {
        return source >= self.source_start and source < self.source_start + self.length;
    }

    pub fn destInRange(self:Conversion, dest:u64) bool {
        return dest >= self.dest_start and dest < self.dest_start + self.length;
    }

    pub fn convert(self: Conversion, source: u64) u64 {
        if (!self.inRange(source)) {
            return source;
        }
        return (source - self.source_start) + self.dest_start;
    }

    pub fn reverseConvert(self: Conversion, dest: u64) u64 {
        if (!self.destInRange(dest)) {
            return dest;
        }
        return (dest - self.dest_start) + self.source_start;
    }
};
test "conversion test" {
    const c1 = Conversion{ .source_start = 0, .dest_start = 100, .length = 10 };
    try expect(c1.inRange(0) == true);
    try expect(c1.inRange(9) == true);
    try expect(c1.inRange(10) == false);
    try expect(c1.inRange(100) == false);
    
    try expect(c1.convert(0) == 100);
    try expect(c1.convert(5) == 105);
    try expect(c1.convert(20) == 20);
}

// Custom sort function for ArrayList(Conversion) 
fn cmpByDestStart(context: void, a: Conversion, b: Conversion) bool {
    _ = context;
    return a.dest_start < b.dest_start;
}
test "custom sort for arraylist of Conversion" {
    const allocator = std.testing.allocator;
    var list = ArrayList(Conversion).init(allocator);
    defer list.deinit();
    try list.append(Conversion{ .dest_start = 50, .source_start = 98, .length = 2 });
    try list.append(Conversion{ .dest_start = 52, .source_start = 50, .length = 48 });
    try list.append(Conversion{ .dest_start = 100, .source_start = 0, .length = 10 });
    try list.append(Conversion{ .dest_start = 0, .source_start = 0, .length = 10 });

    std.mem.sort(Conversion, list.items, {}, cmpByDestStart);
    for (list.items) |conversion| {
        std.debug.print("dest_start: {d}, source_start: {d}, length: {d}\n", .{conversion.dest_start, conversion.source_start, conversion.length});
    }
    try expect(list.items[0].dest_start == 0);
    try expect(list.items[1].dest_start == 50);
    try expect(list.items[2].dest_start == 52);
}


// ConversionSet holds all the conversions for a given source and destination
const ConversionSet = struct{
    // memory for source_name and dest_name are fixed size to avoid heap allocation
    // BoundedArray is the right way to do this. If you used a [] const u8, that would
    // just point to a string owned by the caller, which could be modified at any time
    source_name: std.BoundedArray(u8, 100),
    dest_name: std.BoundedArray(u8, 100),
    conversions_ptr: *ArrayList(Conversion), 

    pub fn init(source_name: []const u8, dest_name: []const u8, conv_ptr: *ArrayList(Conversion)) !ConversionSet {
        // BoundedArray.fromSlice() is the magic here. Remember this, it's useful!
        var sn = try std.BoundedArray(u8,100).fromSlice(source_name);
        var dn = try std.BoundedArray(u8,100).fromSlice(dest_name);
        return ConversionSet{.source_name = sn, 
                             .dest_name = dn, 
                             .conversions_ptr = conv_ptr};
    }

    pub fn convert(self: ConversionSet, source: u64) u64 {
        for (self.conversions_ptr.*.items) |conversion| {
            if (conversion.inRange(source)) {
                return conversion.convert(source);
            }
                
        }
        return source; // if no explicit conversion, return the source
    }

    // Use this to convert a destination number back to a source number (for part 2)
    pub fn reverseConvert(self: ConversionSet, dest: u64) u64 {
        for (self.conversions_ptr.*.items) |conversion| {
            if (conversion.destInRange(dest)) {
                return conversion.reverseConvert(dest);
            }   
        }
        return dest; // if no explicit conversion, return the dest
    }
   
};
test "conversion set test" {
    const allocator = std.testing.allocator;
    var list = ArrayList(Conversion).init(allocator);
    defer list.deinit();
    try list.append(Conversion{ .dest_start = 50, .source_start = 98, .length = 2 });
    try list.append(Conversion{ .dest_start = 52, .source_start = 50, .length = 48 });
    var set = try ConversionSet.init("seed","soil", &list);
 
    try expect(set.convert(79) == 81);
    try expect(set.convert(14) == 14);
    try expect(set.convert(55) == 57);
    try expect(set.convert(13) == 13);
}

pub fn parseSeeds(line: []const u8, seeds_array:*ArrayList(u64)) !bool {
    // Split the line into tokens by whitespace
    var token_iterator = std.mem.split(u8, line, " ");
    if (token_iterator.next()) |token| {
        if (!std.mem.eql(u8, token, "seeds:")) {
            return false;
        }
    }
    while (token_iterator.next()) |token| {
        // Parse the token into a u64
        var seed: u64 = 0;
        var seed_str = std.mem.trim(u8, token, " ");
        if (seed_str.len == 0) {
            continue;
        }
        seed = try std.fmt.parseUnsigned(u64, seed_str, 10);
        // Add the seed to the seeds array
        try seeds_array.append(seed);
    }
    return true;
}
test "parseSeeds test" {
    const allocator = std.testing.allocator;
    var seeds_array = ArrayList(u64).init(allocator);
    defer seeds_array.deinit();
    _ = try parseSeeds("seeds: 10 200 3 44 55555", &seeds_array);
    try expect(seeds_array.items[0] == 10);
    try expect(seeds_array.items[1] == 200);
    try expect(seeds_array.items[2] == 3);
    try expect(seeds_array.items[3] == 44);
    try expect(seeds_array.items[4] == 55555);
}

pub fn parseMapName(line: []const u8) [2][]const u8 {
    var retval: [2][]const u8 = [_][]const u8{"undef", "undef"};
    // Split the line into tokens by whitespace
    var token_iterator = std.mem.split(u8, line, " ");
    if (token_iterator.next()) |token| {
        var names_iterator = std.mem.split(u8, token, "-");
        if (names_iterator.next()) |source_name| {
            retval[0] = source_name;
            if (names_iterator.next()) |to_word| {
                _ = to_word; // ignore the "to" word
                if (names_iterator.next()) |dest_name| {
                    retval[1] = dest_name;
                }
            }
        }
    }
    return retval;
}
test "parseMapName test" {
    var names = parseMapName("seed-to-soil map:");
    var cs = try ConversionSet.init(names[0], names[1]);
    std.debug.print("source: {s}, dest: {s}\n", .{cs.source_name.slice(), cs.dest_name.slice()});
    try expect(std.mem.eql(u8, cs.source_name.slice(), "seed"));
    try expect(std.mem.eql(u8, cs.dest_name.slice(), "soil"));
}

pub fn parseConversion(line: []const u8, conversion_array:*ArrayList(Conversion)) !bool {
    var conversion = Conversion{ .dest_start = 0, .source_start = 0, .length = 0 };
    // Split the line into tokens by whitespace
    var token_iterator = std.mem.split(u8, line, " ");
    // We're looking for exactly three numbers separated by whitespace: destination_start, source_start, length
    // First, destination_start
    if (token_iterator.next()) |token| {
        // Parse the token into a u64
        var destination: u64 = 0;
        destination = try std.fmt.parseUnsigned(u64, token, 10);
        conversion.dest_start = destination;
    }
    // Second, source_start
    if (token_iterator.next()) |token| {
        // Parse the token into a u64
        var source: u64 = 0;
        source = try std.fmt.parseUnsigned(u64, token, 10);
        conversion.source_start = source;
    }
    // Third, length
    if (token_iterator.next()) |token| {
        // Parse the token into a u64
        var length: u64 = 0;
        length = try std.fmt.parseUnsigned(u64, token, 10);
        conversion.length = length;
    }
    try conversion_array.*.append(conversion);
    return true;
}
test "parseConversion test" {
    const allocator = std.testing.allocator;
    var conversion_array = ArrayList(Conversion).init(allocator);
    defer conversion_array.deinit();
    _ = try parseConversion("100 0 10", &conversion_array);
    try expect(conversion_array.items[0].dest_start == 100);
    try expect(conversion_array.items[0].source_start == 0);
    try expect(conversion_array.items[0].length == 10);
}

// Convert a source (seed) number recursively through multiple conversions to a destination number
pub fn convertFromTo(source: u64, source_name: []const u8, dest_name: []const u8, conversion_hashmap:std.StringHashMap(ConversionSet)) u64 {
    var conversion_set = conversion_hashmap.get(source_name); // get the first conversion set from the source type to whatever
    if (conversion_set) |cs| {
        //std.debug.print("Converting {d} from {s} to {s}\n", .{source, cs.source_name.slice(), cs.dest_name.slice()});
        if (std.mem.eql(u8, cs.dest_name.slice(), dest_name)) {
            //std.debug.print("Found final conversion to {s}\n", .{dest_name});
            return cs.convert(source);
        } else {
            return convertFromTo(cs.convert(source), cs.dest_name.slice(), dest_name, conversion_hashmap);
        }
    }
    return source; // if no conversion set, return the source
}


pub fn solvePart(part_num:u8) !u64 {
    var lowest_location: u64 = std.math.maxInt(u64);
    const allocator = std.heap.page_allocator;
    // Hashmap indexed by source name, containing a ConversionSet
    var conversion_hashmap = std.StringHashMap(ConversionSet).init(allocator);  
    try conversion_hashmap.ensureTotalCapacity(10);
    defer conversion_hashmap.deinit(); 

    // Array of seeds we will test to see which one produces the lowest location
    var seeds_array = ArrayList(u64).init(allocator);

    // We need to carefully set up the defer deinit here to deinit each ArrayList(Conversion) in the list
    var conversion_array = ArrayList(ArrayList(Conversion)).init(allocator);
    defer {
        for (conversion_array.items) |conversion| {
            conversion.deinit();
        }
        conversion_array.deinit();
    }
 
    // Open input file and schedule closing it at the end of this block
    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    // Create a 4k buffer to read lines into
    var buf: [4096]u8 = undefined;


    // Read lines from stdin until EOF is reached. Lines are delimited by '\n'
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var trimmed_line = std.mem.trim(u8, line, " ");
        if (trimmed_line.len > 0) {
            // Parse the seeds line if we don't have one yet
            if (seeds_array.items.len == 0) {
                _ = try parseSeeds(trimmed_line, &seeds_array);
            } else {
                // If this is the name of a conversion map, parse it and add it to the hashmap
                if (!std.ascii.isDigit(trimmed_line[0]) and trimmed_line.len > 5) {
                    // Grab the source and destination names from the line
                    var source_dest = parseMapName(trimmed_line);
                    // defer deinit is already handled when we set up the conversion_array
                    try conversion_array.append(ArrayList(Conversion).init(allocator));
            
                    // Create a ConversionSet and add it to the hashmap
                    var conversion_set = try ConversionSet.init(source_dest[0],source_dest[1], &conversion_array.items[conversion_array.items.len - 1]);
                   
                    // Tried lots of other things here as the key argument:
                    // 1. conversion_set.source_name.slice()
                    // 2. conversion_set.source_name.constSlice()
                    // 3. &conversion_set.source_name.buffer
                    // 4. std.mem.dupe(std.heap.page_allocator, u8, conversion_set.source_name.slice())
                    // The only one that worked was #4
                    const source_key:[]const u8 = try std.heap.page_allocator.dupe(u8, conversion_set.source_name.slice());
                    try conversion_hashmap.put(source_key, conversion_set);
                    
                    
                } else {
                    // Otherwise, parse the conversion and add it to the current conversion array
                    const result = try parseConversion(line, &conversion_array.items[conversion_array.items.len - 1]);
                    if (!result) {
                        std.debug.print("Failed to parse conversion line: {s}\n", .{line});
                    } else {
                        //std.debug.print("Parsed conversion line: {s}\n", .{line});
                        //std.debug.print("Conversion array at index {d} has length: {d}\n", .{conversion_array.items.len-1, conversion_array.items[conversion_array.items.len - 1].items.len});
                    }
                }
            }
        }
    }

    // Finally all set up, now go through seeds and find the lowest location

    // Part 2 solution (the faster way): Sort all the conversion arrays by dest_start
    // and work backwards from the location conversion set to find the lowest range of
    // locations, then go up through humidity, temperature, light, water, fertilizer, soil, seed
    var prev_seed: u64 = 0;
    var seed_num: usize = 0;
    // Create an ArrayList of seed ranges as Conversions so we can quickly check them
    var seed_ranges = ArrayList(Conversion).init(allocator);
    defer seed_ranges.deinit();
    // the seed range is only needed for part 2 but it is fast to create
    for (seeds_array.items) |seed| {
        if (seed_num % part_num == 1) { // when part_num==1, this is never true. When part_num==2, this is true every other time
            var seed_range = Conversion{ .dest_start = prev_seed, .source_start = prev_seed, .length = seed };
            try seed_ranges.append(seed_range);
        }
    }
    const reverse_order:[5][]const u8 = [_][]const u8{"temperature", "light", "water", "fertilizer", "soil"};
    var humidity_to_location = conversion_hashmap.get("humidity");
    if (part_num == 2 and humidity_to_location) |h2l| {
        // Sort the humidity-to-location conversion array by dest_start, low to high
        // That gives us the lowest possible location outputs first so we can work backwards efficiently
        std.mem.sort(Conversion, h2l.conversions_ptr.*.items, {}, cmpByDestStart);
        for (h2l.conversions_ptr.*.items) |conversion| {
            // start with the lowest location destination range and work backwards to find any seed ranges that fall 
            // in the range to produce the lowest location in that chain
            std.debug.print("Finding a seed that produces location range {d} to {d}...\n", .{conversion.dest_start, conversion.dest_start + conversion.length});
            var low_value_to_get = conversion.source_start;
            var high_value_to_get = conversion.source_start + conversion.length;
            for (low_value_to_get..high_value_to_get) | value_to_get | {
                var val = value_to_get; // need var not const here
                for (reverse_order) |set_name| { //temperature, light, water, fertilizer, soil
                    var conversion_set = conversion_hashmap.get(set_name);
                    if (conversion_set) |cs| {
                        val = cs.reverseConvert(val);
                    }
                }
                // Now we've ended up with the seed number that is required to produce the lowest location
                // Check to see if it is in any of the seed ranges
                for (seed_ranges.items) |seed_range| {
                    if (seed_range.inRange(val)) {
                        std.debug.print("!! Found the seed that produces the lowest location: {d}\n", .{val});
                        var location = convertFromTo(val, "seed", "location", conversion_hashmap);
                        std.debug.print("Seed {d} produces location {d}\n", .{val, location});
                        lowest_location = location;
                        break;
                    }
                }
            }   
        }
    }
    
    prev_seed = 0;
    seed_num = 0;
    for (seeds_array.items) |seed| {
        var location = convertFromTo(seed, "seed", "location", conversion_hashmap);
        // This is all we need to do differently for part 2, the straightforward but VERY slow way
        // if (seed_num % part_num == 1) { // when part_num==1, this is never true. When part_num==2, this is true every other time
        //     std.debug.print("Checking seed range: {d} to {d}, prev_seed: {d}\n", .{prev_seed, prev_seed+seed});
        //     for (prev_seed..prev_seed+seed) |i| {
        //         location = convertFromTo(i, "seed", "location", conversion_hashmap);
        //     }
        // }
        // End of part two difference
        // Note: this is unacceptably slow. 
        // Better plan: work backwards from the lowest location conversion line:
        // 0 262282387 23738616
        
        if (location < lowest_location) {
            lowest_location = location;
        }
        prev_seed = seed;
        seed_num += 1;
    }

    return lowest_location;
}

pub fn main() !void {
    var lowest_location = try solvePart(1);
    std.debug.print("Part 1 (lowest location): {d}\n", .{lowest_location});

    lowest_location = try solvePart(2);
    std.debug.print("Part 2 (lowest location): {d}\n", .{lowest_location});
}

