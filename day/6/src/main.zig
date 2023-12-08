const std = @import("std");

const Race = struct {
    time: u32,
    distance: u32,
};
const RaceList = std.MultiArrayList(Race);

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const times:[4]u32 = [_]u32{47, 98, 66, 98};
    const distances:[4]u32 = [_]u32{400, 1213, 1011, 1540};
    var races = RaceList{};
    defer races.deinit(allocator);
    for (0..times.len) |i| {
        try races.append(allocator, .{ .time = times[i], .distance = distances[i] });
    }

    var answer_part_one:u32 = 1;
    for (races.items(.time), races.items(.distance)) |time, distance| {
        var num_wins:u32 = 0;
        for (1..time) |hold_ms| {
            if ((time-hold_ms)*hold_ms > distance) {
                num_wins += 1;
            }
        }
        answer_part_one *= num_wins;
    }
    std.debug.print("Part 1: {d}\n", .{answer_part_one});

    // Part 2
    const time:u64 = 47986698;
    const distance:u64 = 400121310111540;
    var answer_part_two:u64 = 0;
    for (1..time) |hold_ms| {
        if ((time-hold_ms)*hold_ms > distance) {
            answer_part_two += 1;
        }
    }
    std.debug.print("Part 2: {d}\n", .{answer_part_two});
}
