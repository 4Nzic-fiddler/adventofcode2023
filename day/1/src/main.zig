const std = @import("std");
const fmt = std.fmt;
const unicode = @import("std").unicode;
// ziglyph is a library for working with Unicode graphemes
const zg = @import("ziglyph");
const Grapheme = zg.Grapheme;
const GraphemeIterator = Grapheme.GraphemeIterator;

pub fn inSlice(comptime T: type, haystack: []const u8, needle: T) bool {
    for (haystack) |thing| {
        if (thing == needle) {
            return true;
        }
    }
    return false;
}

pub fn startsWith(comptime T: type, haystack: []const T, needle: []const T) bool {
    if (needle.len > haystack.len) {
        return false;
    }
    for (needle, 0..) |thing, i| {
        if (thing != haystack[i]) {
            return false;
        }
    }
    return true;
}

pub fn main() !void {
    // Keep the running sum of the calibration values 
    var calibration_sum: u64 = 0;

    // Determine whether we'll calculate values for challenge 1 or 2
    var challenge: u8 = 2;


    // define words that are digits as a StringHashMap -- this is a bit overkill, but it's a good reference
    //const allocator = std.heap.page_allocator;
    //var digit_words = std.StringHashMap(u8).init(allocator);
    //try digit_words.put("zero", 0);
    //try digit_words.put("one", 1);
    //try digit_words.put("two", 2);
    //try digit_words.put("three", 3);
    //try digit_words.put("four", 4);
    //try digit_words.put("five", 5);
    //try digit_words.put("six", 6);
    //try digit_words.put("seven", 7);
    //try digit_words.put("eight", 8);
    //try digit_words.put("nine", 9);

    // a simpler way to define just an array of strings and use index as the digit (no need for a HashMap)
    var digit_words2 = [_][]const u8{"zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"};

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
            // We need to find the first and last digits in the line
            var digit1:u64 = 0;
            var digit2:u64 = 0;
            
            // Let's just make an assumption that each character is one Unicode code point.
            // It simplifies things a lot, and it's probably true for this input.
            var iter = (try unicode.Utf8View.init(line)).iterator();
            // second iterator lags one codepoint behind the first to make it easy to pull a possible word with peek()
            var iter2 = (try unicode.Utf8View.init(line)).iterator();
            while (iter.nextCodepoint()) |codepoint| {
                // Note that a Unicode codepoint is a u21 type in Zig -- it's not a u32 as in other languages

                //std.debug.print("codepoint: {x}\n", .{codepoint});
                // Check if the codepoint is a digit -- if so, convert it to a number
                // Note: neither fmt.ParseInt nor zg.toDigit will work with a Unicode codepoint u21 argument :-/
                if (codepoint >= 0x30 and codepoint <= 0x39) {
                    //std.debug.print("codepoint: {d}\n", .{codepoint});
                    if (digit1 == 0) {
                        digit1 = codepoint - 0x30; //fmt.parseInt(i32, codepoint, 10); //zg.toDigit(codepoint, 10);
                    } else {
                        digit2 = codepoint - 0x30; //fmt.parseInt(i32, codepoint, 10); //zg.toDigit(codepoint, 10);
                    }
                }

                // For challenge 2 only: Check if the codepoint is the start of a digit word
                if (challenge == 2 and inSlice(u21, "zotfsen", codepoint)) {
                    // Peek at the next letters from the iterator (at most five letters)
                    const maybe_digit_word: []const u8 = iter2.peek(5);
                    //std.debug.print("maybe_digit_word: {s}\n", .{maybe_digit_word});
                    for (digit_words2, 0..) |digit_word, digit| {
                        if (startsWith(u8, maybe_digit_word, digit_word)) {
                            std.debug.print("digit_word: {s}\n", .{digit_word});
                            std.debug.print("digit: {d}\n", .{digit});
                            if (digit1 == 0) {
                                digit1 = digit;
                            } else {
                                digit2 = digit;
                            }
                        }
                    }
                }
                _ = iter2.nextCodepoint();
            }

            // Ziglyph failure - I wanted to iterate over the graphemes in the line 
            // (because a unicode grapheme can be more than one code point),
            // but I couldn't manage to get a single Unicode code point out of a Grapheme
            // object. I think Grapheme.slice() is the answer, but I couldn't get it to work.
            
            // Iterate over the characters in the line, one grapheme at a time
          //  var iter = GraphemeIterator.init(line);
          //  while (iter.next()) |grapheme| {
          //      // Check if the grapheme is a digit -- if so, convert it to a number
          //      // Note that we'll only consider graphemes with exactly one code point to be digits
          //      if (grapheme.len == 1) {
          //      
          //          const s: []const u8 = grapheme.slice([0]);
          //          var char:u8 = s[0];
          //          if (zg.isDigit(char)) {
          //              if (digit1 == -1) {
          //                  digit1 = char.toDigit(10);
          //              } else {
          //                  digit2 = char.toDigit(10);
          //              }
          //          }
          //      }
          //  }
            //std.debug.print("digit1: {d}, digit2: {d}\n", .{digit1, digit2});
            if (digit1 != 0) {
                if (digit2 == 0) digit2 = digit1;
                std.debug.print("Two digit number is: {d}{d}\n", .{digit1, digit2});
                calibration_sum += (digit1*10) + digit2;
            }
        }
    }
    std.debug.print("Calibration sum: {d}\n", .{calibration_sum});
}
