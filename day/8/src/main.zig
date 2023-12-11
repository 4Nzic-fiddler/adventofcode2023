const std = @import("std");
const expect = std.testing.expect;

const Node = extern struct{
    name: [3]u8,
    L: *const Node,
    R: *const Node,
    LName: [3]u8,
    RName: [3]u8,

    pub fn init(name: []const u8, LName: []const u8, RName: []const u8) Node {
        return Node{.name = [_]u8{name[0], name[1], name[2]}, 
        .L = undefined, .R = undefined, 
        .LName = [_]u8{LName[0], LName[1], LName[2]}, 
        .RName = [_]u8{RName[0], RName[1], RName[2]}};
    }

    pub fn setLeft(self: *Node, node: ?*const Node) void {
        if (node) |valid_node| {
            self.L = valid_node;
        }
    }

    pub fn setRight(self: *Node, node: ?*const Node) void {
        if (node) |valid_node| {
            self.R = valid_node;
        }   
    }
    
    pub fn stepsToFindNodeEndingIn(self: *Node, end_condition: u8, directions: []const u8) usize {
        var current_node = self;
        var step: usize = 0;
        // Follow directions Left and Right until we get to the FIRST node ending in 'Z' or whatever
        while (current_node.name[2] != end_condition) {
            if (directions[step % directions.len] == 'L') {
                current_node = current_node.L;
            } else if (directions[step % directions.len] == 'R') {
                current_node = current_node.R;
            } else {
                std.debug.print("Invalid direction: {c}\n", .{directions[step]});
                break;
            }
            step = (step + 1);
        }
        return step;
    }
};
test "init Node" {
    var node = Node.init("abc", "def", "ghi");
    try expect(std.mem.eql(u8, &node.name, "abc"));
    try expect(std.mem.eql(u8, &node.LName, "def"));
    try expect(std.mem.eql(u8, &node.RName, "ghi"));
}

test "setLeft" {
    var node = Node.init("abc", "def", "ghi");
    var node2 = Node.init("def", "456", "789");
    node.setLeft(&node2);
    try expect(node.L == &node2);
}

test "setRight" {
    var node = Node.init("abc", "def", "ghi");
    var node2 = Node.init("ghi", "456", "789");
    node.setRight(&node2);
    try expect(node.R == &node2);
}

/// NodeCycle is a struct that keeps track of a cycle of steps that starts and ends at the same node
/// and direction. It's used to find the repeat period of a ghost and the steps required to hit
/// each of the end condition nodes that are reachable from the start node.
/// Note: Only use the init() and deinit() functions to create and destroy a NodeCycle
const NodeCycle = struct { 
    start_node: *const Node,
    end_condition: u8,
    first_end_step: usize,
    first_end_node: *const Node,
    end_step_cycle: std.ArrayList(usize),
    current_end_step: usize,
    current_step: usize,

    pub fn init(allocator:std.mem.Allocator, start_node: *const Node, end_condition: u8) NodeCycle {
        return NodeCycle{.start_node = start_node, .end_condition = end_condition, 
        .first_end_step = 0, .first_end_node = start_node, 
        .end_step_cycle = std.ArrayList(usize).init(allocator), 
        .current_end_step=0, .current_step = 0};
    }

    pub fn deinit(self: *NodeCycle) void {
        self.end_step_cycle.deinit();
    }

    pub fn stepsToFirstMatch(self: *NodeCycle, directions: []const u8) usize {
        var current_node = self.start_node;
        var step: usize = 0;
        // Follow directions Left and Right until we get to the FIRST node ending in 'Z' or whatever
        while (current_node.name[2] != self.end_condition) {
            if (directions[step % directions.len] == 'L') {
                current_node = current_node.L;
            } else if (directions[step % directions.len] == 'R') {
                current_node = current_node.R;
            } else {
                std.debug.print("Invalid direction: {c}\n", .{directions[step]});
                break;
            }
            step = (step + 1);
        }
        self.first_end_node = current_node;
        self.first_end_step = step;
        std.debug.print("stepsToFirstMatch found {s} at step {d}\n", .{current_node.name, step});
        return step;
    }

    pub fn findFirstEndStep(self: *NodeCycle, directions: []const u8) usize {
        var step: usize = self.stepsToFirstMatch(directions);
        self.first_end_step = step;
        return step;
    }

    /// Given a list of directions, find the shortest cycle of steps that hit all end conditions
    /// that are reachable for this node and end up back at the start node and direction
    pub fn findCycle(self: *NodeCycle, directions: []const u8) !usize {
        const direction_to_match:u8 = directions[self.first_end_step % directions.len];
        std.debug.print("Node {s}: findCycle started on step {d} at node {s} about to go {c}\n", .{self.start_node.name, self.first_end_step, self.first_end_node.name, direction_to_match});
        // Start searching at the next node after start_node
        var current_node = switch (direction_to_match) {
            'L' => self.first_end_node.L,
            'R' => self.first_end_node.R,
            else => self.first_end_node,
        };
        // Keep track of how many steps since the last matching node
        var step: usize = self.first_end_step + 1;
        var steps_since_last_match: usize = 1;
        // Follow directions Left and Right until we loop around to our first matching node AND direction
        while (current_node != self.first_end_node or directions[step % directions.len] != direction_to_match) {
            // Keep track when we reach each end condition node
            if (current_node.name[2] == 'Z') {
                std.debug.print("Node {s}: findCycle found {s} at step {d}\n", .{self.start_node.name, current_node.name, step});
                try self.end_step_cycle.append(steps_since_last_match);
                steps_since_last_match = 0;
            } 
            if (directions[step % directions.len] == 'L') {
                current_node = current_node.L;
            } else if (directions[step % directions.len] == 'R') {
                current_node = current_node.R;
            } else {
                std.debug.print("Invalid direction: {c}\n", .{directions[step]});
                break;
            }
            step = (step + 1);
            steps_since_last_match = (steps_since_last_match + 1);
        }
        // Add the last step count to the end_step_cycle
        try self.end_step_cycle.append(steps_since_last_match);
        std.debug.print("Node {s}: findCycle finished on step {d} at node {s}\n", .{self.start_node.name, step, current_node.name});
        std.debug.print("end_step_cycle: [", .{});
        for (self.end_step_cycle.items) |step_item| {
            std.debug.print("{d}, ", .{step_item});
        }
        std.debug.print("]\n", .{});
        return steps_since_last_match;
    }

    pub fn nextEndCondition(self: *NodeCycle) usize {
        self.current_end_step = (self.current_end_step + 1) % self.end_step_cycle.items.len;
        self.current_step += self.end_step_cycle.items[self.current_end_step];
        //std.debug.print("Node {s} skipped {d} steps to get to step {d}\n", .{self.start_node.name, self.end_step_cycle.items[self.current_end_step], self.current_step});
        return self.current_step;
    }

    pub fn advanceUntilGreaterOrEqualTo(self: *NodeCycle, target_step: usize) usize {
        while (self.current_step < target_step) {
            _ = self.nextEndCondition();
        }
        return self.current_step;
    }
};
test "test NodeCycle" {
    var nodeA = Node.init("AAA", "BBB", "CCC");
    var nodeB = Node.init("BBB", "DDD", "CCC");
    var nodeC = Node.init("CCC", "BBB", "AAA");
    var nodeD = Node.init("DDD", "11Z", "AAA");
    var node11Z = Node.init("11Z", "BBB", "CCC");
    const directions: []const u8 = "LRRLRLRRRLLLR";
    nodeA.setLeft(&nodeB);
    nodeA.setRight(&nodeC);
    nodeB.setLeft(&nodeD);
    nodeB.setRight(&nodeC);
    nodeC.setLeft(&nodeB);
    nodeC.setRight(&nodeA);
    nodeD.setLeft(&node11Z);
    nodeD.setRight(&nodeA);
    node11Z.setLeft(&nodeB);
    node11Z.setRight(&nodeC);
    var node_cycle = NodeCycle.init(std.testing.allocator, &nodeA, 'Z');
    
    _ = node_cycle.findFirstEndStep(directions);
    _ = try node_cycle.findCycle(directions); // 
    std.debug.print("length of cycle: {d}\n", .{node_cycle.end_step_cycle.items.len});
    try expect(node_cycle.start_node == &nodeA);
    try expect(node_cycle.end_condition == 'Z');
    try expect(node_cycle.first_end_step == 12);
    std.debug.print("len: {d} ", .{node_cycle.end_step_cycle.items.len});
    try expect(node_cycle.end_step_cycle.items.len == 1);
    try expect(node_cycle.current_end_step == 0);
    try expect(node_cycle.current_step == 0);
    node_cycle.deinit();
}


pub fn main() !void {
    const allocator = std.heap.page_allocator;
    // Create a map of node names to nodes
    var node_map = std.StringHashMap(Node).init(allocator);
    defer node_map.deinit();
   
    // Open input file and schedule closing it at the end of this block
    var file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    // Create a 4k buffer to read lines into
    var buf: [4096]u8 = undefined;
    // and a separate buffer to hold the directions line until the end
    var directions_buf: [4096]u8 = undefined;

    // First read the line of directions (LRRLRLRRRLLLR...)
    // Important note: We need to store the directions in a separate buffer from the
    // one we're using to read in the other lines, otherwise, it gets overwritten before we use it
    if (try in_stream.readUntilDelimiterOrEof(&directions_buf, '\n')) |directions| {
        // Read lines from stdin until EOF is reached. Lines are delimited by '\n'
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var trimmed_line = std.mem.trim(u8, line, " ");
            if (trimmed_line.len > 0) {
                var token_iterator = std.mem.split(u8, trimmed_line, " ");
                if (token_iterator.next()) |node_name| {
                    if (token_iterator.next()) |equal_sign| {
                        _ = equal_sign; // ignore the equal sign
                        if (token_iterator.next()) |LName| {
                            if (token_iterator.next()) |RName| {
                                // At this point for input AAA = (BBB, CCC) we have:
                                // node_name = "AAA"
                                // LName = "(BBB,"  (so we want LName[1..] to get rid of the '(')
                                // RName = "CCC)" (fine, we'll just use the first 3 characters anyway)
                                var node = Node.init(node_name, LName[1..], RName);
                                const node_key:[]const u8 = try std.heap.page_allocator.dupe(u8, &node.name);
                                std.debug.print("node: {s} L={s} R={s}\n", .{node.name, node.LName, node.RName});
                                try node_map.put(node_key, node); // Note: we can't just use node_name or node.name for the key
                            }
                        }
                    }
                }
            }
        }
        // Practically speaking, at this point we could just use our HashMap as the tree,
        // but HashMap is slower and we love our pointers, so let's create proper tree of Nodes
        var nodes_iterator = node_map.iterator();
        while (nodes_iterator.next()) |kv| {
            var node_ptr = kv.value_ptr;
            // I'm sorry, Zig, but this syntax is just ugly. Your baby is ugly. I said it.
            if (node_map.getPtr(&node_ptr.LName)) |LNode| { // Note: use getPtr, not get!
                node_ptr.*.setLeft(LNode);
            }
            if (node_map.getPtr(&node_ptr.RName)) |RNode| {
                node_ptr.*.setRight(RNode);
            }
        } // done building the tree

        // Go through our LR directions and find our way to the end
        std.debug.print("Directions: {s}\n", .{directions} );
        if (node_map.get("AAA") ) |start_node| {
            var current_node = &start_node;
            var step: usize = 0;
            // Follow directions Left and Right until we get to the Node named ZZZ
            while (!std.mem.eql(u8, &current_node.name, "ZZZ")) {
                if (directions[step % directions.len] == 'L') {
                    current_node = current_node.L;
                    //std.debug.print("Going Left to {s}\n", .{current_node.name});
                } else if (directions[step % directions.len] == 'R') {
                    current_node = current_node.R;
                    //std.debug.print("Going Right to {s}\n", .{current_node.name});
                } else {
                    std.debug.print("Invalid direction: {c}\n", .{directions[step]});
                    break;
                }
                step = (step + 1);
            }
            std.debug.print("Final node: {s}\n", .{current_node.name});
            std.debug.print("Part one answer: Reached in {d} steps\n", .{step});
        } // end if we found the start node


        // Part two: Ghosts!
        // First find every node name that ends in 'A' and create an ArrayList of pointers to them
        var ghosts = std.ArrayList(*const Node).init(allocator);
        defer ghosts.deinit();
        nodes_iterator = node_map.iterator();
        while (nodes_iterator.next()) |kv| {
            var node_ptr = kv.value_ptr;
            if (node_ptr.*.name[2] == 'A') {
                try ghosts.append(node_ptr);
            }
        }
        // New (MUCH FASTER!) approach: find the repeat period of each ghost, then compute LCM of all periods.
        // To encapsulate this, we'll create a NodeCycle for each ghost
        var node_cycles = std.ArrayList(NodeCycle).init(allocator);
        defer {
            // need to destroy each NodeCycle before destroying the ArrayList
            for (node_cycles.items) |node_cycle| {
                var node_ptr = node_cycle;
                node_ptr.deinit();
            }
            node_cycles.deinit();
        }
        var lcm_of_cycles: usize = 1;
        var max_step:usize = 0;
        for (ghosts.items) |node| {
            try node_cycles.append(NodeCycle.init(allocator, node, 'Z'));
            var node_cycle = &node_cycles.items[node_cycles.items.len - 1];
            var first_end_step = node_cycle.findFirstEndStep(directions);
            // Keep track of which node cycle is on the highest step
            if (first_end_step > max_step) {
                max_step = first_end_step;
            }
            const cycle_length = try node_cycle.findCycle(directions); 
            lcm_of_cycles = lcm(lcm_of_cycles, cycle_length); // update the LCM
            std.debug.print("Node {s} cycle length: {d}, LCM is now={d}\n", .{node.name, cycle_length, lcm_of_cycles});
        }
        std.debug.print("Answer to part 2: LCM of cycles: {d}\n", .{lcm_of_cycles});

        // This is the slow way: simultaneously follow the directions for each ghost
        // var step:usize = 0;
        // while (numNodesEndInZ(&ghosts) < ghosts.items.len) {
        //     if (numNodesEndInZ(&ghosts) > 3) {
        //         std.debug.print("Step {d}, Ghosts at: ", .{step});
        //         for (0..ghosts.items.len) |i| {
        //             std.debug.print("{s} ", .{ghosts.items[i].name});
        //         }
        //         std.debug.print("\n", .{});
        //     }
            
        //     for (0..ghosts.items.len) |i| {
        //         if (directions[step % directions.len] == 'L') {
        //             ghosts.items[i] = ghosts.items[i].*.L;
        //         } else if (directions[step % directions.len] == 'R') {
        //             ghosts.items[i] = ghosts.items[i].*.R;
        //         } else {
        //             std.debug.print("Invalid direction: {c}\n", .{directions[step]});
        //             break;
        //         }
        //     }
        //     //std.debug.print("\n", .{});
        //     step = (step + 1);
        // }
        // std.debug.print("Final nodes:\n", .{});
        // for (ghosts.items) |node| {
        //     std.debug.print("{s} ", .{node.name});
        // }
        // std.debug.print("\n\nPart two answer: All ghosts reached **Z in {d} steps\n", .{step});
        
    } // end if we got the line of directions

    
} // end of main 

/// Greatest Common Divisor
pub fn gcd(a_const: usize, b_const: usize) usize {
    var a = a_const;
    var b = b_const;
    while (b != 0) {
        var t = b;
        b = a % b;
        a = t;
    }
    return a;
}

/// Least Common Multiple
pub fn lcm(a: usize, b: usize) usize {
    return (a * b) / gcd(a, b);
}

pub fn numNodesEndInZ(nodes: *std.ArrayList(*const Node)) usize {
    var numZ: usize = 0;
    for (nodes.items) |node| {
        if (node.name[2] == 'Z') {
            numZ += 1;
        }
    }
    return numZ;
}