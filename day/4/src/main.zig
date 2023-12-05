const std = @import("std");


const Card = struct{
    card_num: u32,
    score: u32,
    num_winning_numbers: u32,
};

pub fn getScoreForCard(card_line: []const u8) !Card {
    var card = Card{ .card_num = 0, .score = 0, .num_winning_numbers = 0 };
    const allocator = std.heap.page_allocator;
    var winning_numbers = std.StringHashMap(bool).init(allocator);
    defer winning_numbers.deinit();

    // Split line by ':' to get "Card #" and the rest of the line
    var token_iterator = std.mem.split(u8, card_line, ":");
    if (token_iterator.next()) |token| {
        var card_and_num = std.mem.trim(u8, token, " ");
        // Now split the Card string from the number
        var card_num_iterator = std.mem.split(u8, card_and_num, " ");
        if (card_num_iterator.next()) |card_str| {
            // Verify that the first token is "Card" otherwise this line is malformed
            if (std.mem.eql(u8, card_str, "Card")) {
                // Now we have the card number, parse it
                if (card_num_iterator.next()) |card_num_str| { 
                    card.card_num = std.fmt.parseInt(u32, card_num_str, 10) catch 0;
                } 
            }
        }
    }
    // Get the rest of the line
    if (token_iterator.next()) |token| {
        // Now split the winning number list from the have_numbers list by |
        var rest_of_line = std.mem.trim(u8, token, " ");
        var rest_of_line_iterator = std.mem.split(u8, rest_of_line, "|");
        // Get the winning numbers string list
        if (rest_of_line_iterator.next()) |line_part| {
            var winning_numbers_str = std.mem.trim(u8, line_part, " ");
            // Now split the winning numbers string list by spaces
            var winning_numbers_str_iterator = std.mem.split(u8, winning_numbers_str, " ");
            // Add each winning number to the winning_numbers hashmap
            // (Note: we'll just keep them as strings for now to avoid integer parsing)
            while (winning_numbers_str_iterator.next()) |winning_number_str| {
                var winning_number = std.mem.trim(u8, winning_number_str, " ");
                if (winning_number.len == 0) {
                    continue;
                }
                try winning_numbers.put(winning_number, true);
                //std.debug.print("Added winning number {s}\n", .{winning_number});
            }
        }
        // Now get the have_numbers string list and check each one against the winning_numbers hashmap
        if (rest_of_line_iterator.next()) |line_part| {
            var have_numbers_str = std.mem.trim(u8, line_part, " ");
            // Now split the have_numbers string list by spaces
            var have_numbers_str_iterator = std.mem.split(u8, have_numbers_str, " ");
            // Check each have_number against the winning_numbers hashmap
            while (have_numbers_str_iterator.next()) |have_number_str| {
                var have_number = std.mem.trim(u8, have_number_str, " ");
                if (have_number.len == 0) {
                    continue;
                }
                if (winning_numbers.contains(have_number)) {
                    //std.debug.print("Card {d} has winning number {s}\n", .{card.card_num, have_number});
                    card.num_winning_numbers += 1;
                    if (card.score == 0) {
                        card.score = 1;
                    } else {
                        card.score *= 2; // double the score
                    }
                }
            }
        }
    }

    return card;
}

pub fn solvePartOne() !u32 {
    var score:u32 = 0;
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
            const card = try getScoreForCard(line);
            score += card.score;
        }
    }
    return score;
}

// This is a recursive function that calculates the solution to part two
// after all the cards and number of winning numbers have been added to the cards_array
pub fn countCardsAndCopies(cards_array:std.ArrayList(Card), card_index:u64) u32 {
    var total_cards:u32 = 1; // count this card, whether it's a winner or not
    if (card_index >= cards_array.items.len) {
        return total_cards;
    }
    var card = cards_array.items[card_index];
    // These are the copies:
    for (card_index+1..card_index+card.num_winning_numbers+1) |next_card_index| {
        total_cards += countCardsAndCopies(cards_array, next_card_index);
    }
    return total_cards;
}

pub fn solvePartTwo() !u32 {
    var total_cards:u32 = 0;
    var cards_array = std.ArrayList(Card).init(std.heap.page_allocator);
    defer cards_array.deinit();
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
            const card = try getScoreForCard(line);
            try cards_array.append(card);
        }
    }

    
    // Now calculate how many total cards we got by counting copies of each card
    // Here's how to do a for loop with an index in Zig:
    for (0..cards_array.items.len) |i| {
        // and this is a recursive function that calculates the count 
        // efficiently, without copying any cards in memory.
        total_cards += countCardsAndCopies(cards_array, i);
    }
   

    return total_cards;
}


pub fn main() !void {
    var score = try solvePartOne();
    std.debug.print("\nPart 1 Score: {}\n", .{score});

    var total_cards = try solvePartTwo();
    std.debug.print("\nPart 2 Total Cards: {}\n", .{total_cards});
}
