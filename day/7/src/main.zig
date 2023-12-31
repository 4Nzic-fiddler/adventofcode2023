const std = @import("std");
const expect = std.testing.expect;

/// A struct representing a single game (hand of five cards and bid)
const Game = extern struct {
    hand: [5]u8,
    bid: u32,
    jokers_not_jacks: bool,
    hand_type: enum(c_int) {
        HighCard=0,
        Pair=1,
        TwoPair=2,
        ThreeOfAKind=3,
        FullHouse=4,
        FourOfAKind=5,
        FiveOfAKind=6,
    },

    pub fn init(hand: []const u8, bid: u32, jokers:bool) Game {
        var self: Game = .{
            .hand = [_]u8{0,0,0,0,0},
            .bid = bid,
            .jokers_not_jacks = jokers,
            .hand_type = undefined,
        };
        // Copy VALUES, not pointer to array!
        if (jokers) {
            for (0..5) |i| {
                self.hand[i] = switch (hand[i]) {
                    'T' => 10,
                    'J' => 0,
                    'Q' => 11,
                    'K' => 12,
                    'A' => 13,
                    '1'...'9' => hand[i] - '0',
                    else => 0,
                };
            }
        } else {
            for (0..5) |i| {
                self.hand[i] = switch (hand[i]) {
                    'T' => 9,
                    'J' => 10,
                    'Q' => 11,
                    'K' => 12,
                    'A' => 13,
                    '1'...'9' => hand[i] - '0' - 1,
                    else => 0,
                };
            }
        }
        
        self.setHandType();
        return self;
    }

    pub fn printHand(self:Game) void {
        var c:u8 = undefined;
        if (self.jokers_not_jacks) {
            for (0..5) |i| {
                c = switch (self.hand[i]) {
                    0 => 'J', // Joker
                    10 => 'T',
                    11 => 'Q',
                    12 => 'K',
                    13 => 'A',
                    1...9 => self.hand[i] + '0',
                    else => '?',
                };
                std.debug.print("{c}", .{c});
            }
        } else {
            for (0..5) |i| {
                c = switch (self.hand[i]) {
                    9 => 'T',
                    10 => 'J', // Jack
                    11 => 'Q',
                    12 => 'K',
                    13 => 'A',
                    0...8 => self.hand[i] + '0' + 1,
                    else => '?',
                };
                std.debug.print("{c}", .{c});
            }
        }
        
        std.debug.print("\n", .{});
    }

    /// compareTo returns 1 if self is greater than other, 0 if equal, and -1 if less than
    pub fn compareTo(self:Game, other:Game) i8 {
        if (self.hand_type == other.hand_type) {
            for (0..5) |i| {
                if (self.hand[i] > other.hand[i]) {
                    return 1;
                } else if (self.hand[i] < other.hand[i]) {
                    return -1;
                }
            }
            return 0; // same hand exactly
        }
        return if (@intFromEnum(self.hand_type) > @intFromEnum(other.hand_type)) 1 else -1;
    }

    pub fn setHandType(self:*Game) void{
        // Count the number of each card value
        var counts: [14]u8 = [_]u8{0}**14; // initialize all to 0
        // Count the number of each card value
        for (0..5) |i| {
            counts[self.hand[i]] += 1;
        }

        var pair_count:u8 = 0;
        var three_count:u8 = 0;
        var four_count:u8 = 0;
        var five_count:u8 = 0;
        // If J means Joker instead of Jack, then we will NOT count card 0 (Joker) as a pair
        var index_of_one:u8 = if (self.jokers_not_jacks) 1 else 0;
        for (index_of_one..14) |i| {
            if (counts[i]==2) {pair_count += 1;}
            else if (counts[i]==3) {three_count += 1;}
            else if (counts[i]==4) {four_count += 1;}
            else if (counts[i]==5) {five_count += 1;}
        }
        // Make Jokers increase pairs to threes, threes to fours, etc.
        if (self.jokers_not_jacks) {
            // Iterate through the jokers, increasing hand value each time
            for (0..counts[0]) |x| {
                _ = x; // unused
                // Go in order from best to worst hand
                if (four_count > 0) {
                    // If we had any four of a kind before, make it five of a kind
                    four_count -= 1;
                    five_count += 1;
                } else if (three_count > 0) {
                    // Three of a kind becomes four of a kind
                    three_count -= 1;
                    four_count += 1;
                } else if (pair_count == 2) {
                    // Two pair becomes full house
                    pair_count -= 1;
                    three_count += 1;
                } else if (pair_count > 0) {
                    // Pair becomes three of a kind
                    pair_count -= 1;
                    three_count += 1;
                } else {
                    // No pairs, so make it a pair
                    pair_count += 1;
                }
            }
        }

        if (five_count == 1) {
            self.hand_type = .FiveOfAKind;
        } else if (four_count == 1) {
            self.hand_type = .FourOfAKind;
        } else if (three_count == 1 and pair_count == 1) {
            self.hand_type = .FullHouse;
        } else if (three_count == 1) {
            self.hand_type = .ThreeOfAKind;
        } else if (pair_count == 2) {
            self.hand_type = .TwoPair;
        } else if (pair_count == 1) {
            self.hand_type = .Pair;
        } else {
            self.hand_type = .HighCard;
        }
    }
};

// Custom sort function for ArrayList(Game) 
fn cmpByHand(context: void, a: Game, b: Game) bool {
    _ = context;
    return (a.compareTo(b) == -1);
}
test "custom sort for arraylist of Game" {
    const allocator = std.testing.allocator;
    var list = std.ArrayList(Game).init(allocator);
    defer list.deinit();
    try list.append(Game.init("2427T", 2));
    try list.append(Game.init("2467T", 1));
    try list.append(Game.init("KKQQJ", 4));
    try list.append(Game.init("AA67T", 3));
    

    std.mem.sort(Game, list.items, {}, cmpByHand);
    std.debug.print("Sorting hand...\n", .{});
    for (list.items) |game| {
        game.printHand();
        std.debug.print("hand type {s}\n", .{@tagName(game.hand_type)});
        std.debug.print("bid: {d}\n", .{game.bid});
        
    }
    try expect(list.items[0].bid == 1);
    try expect(list.items[1].bid == 2);
    try expect(list.items[2].bid == 3);
    try expect(list.items[3].bid == 4);
}

pub fn solvePart(part_num:u8) !u64 {
    // In part two, J means Joker not Jack
    const jokers_not_jacks:bool = (part_num == 2);
    var result:u32 = 0;
    const allocator = std.heap.page_allocator;
    var games: std.ArrayList(Game) = std.ArrayList(Game).init(allocator);
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
            var token_iterator = std.mem.split(u8, trimmed_line, " ");
            if (token_iterator.next()) |hand_str| {
                if (token_iterator.next()) |bid_str| {
                    var bid:u32 = try std.fmt.parseInt(u32, bid_str, 10);
                    try games.append(Game.init(hand_str, bid, jokers_not_jacks));
                }
            }
        }
    }
    // Sort the games by rank of hand
    std.mem.sort(Game, games.items, {}, cmpByHand);
    var rank:u32 = 1;
    for (games.items) |game| {
        std.debug.print("Rank {d}: ", .{rank});
        game.printHand();
        std.debug.print("hand type {s} ", .{@tagName(game.hand_type)});
        std.debug.print("bid: {d}\n", .{game.bid});
        result += game.bid * rank;
        rank += 1;
    }

    return result;
}

pub fn main() !void {
    const answer_one = try solvePart(1);
    std.debug.print("Answer Part One: {d}\n", .{answer_one});

    const answer_two = try solvePart(2);
    std.debug.print("Answer Part Two: {d}\n", .{answer_two});
}
