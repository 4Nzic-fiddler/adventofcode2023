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
};
test "init Node" {
    var node = Node.init("abc", "def", "ghi");
    try expect(std.mem.eql(u8, &node.name, "abc"));
    try expect(std.mem.eql(u8, &node.LName, "def"));
    try expect(std.mem.eql(u8, &node.RName, "ghi"));
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
                                // RName = "CCC)" (we'll just use the first 3 characters anyway)
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
        // but we love our pointers, so let's create proper tree of Nodes
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
        // Now we can simultaneously follow the directions for each ghost
        var step:usize = 0;
        while (numNodesEndInZ(&ghosts) < ghosts.items.len) {
            if (numNodesEndInZ(&ghosts) > 3) {
                std.debug.print("Step {d}, Ghosts at: ", .{step});
                for (0..ghosts.items.len) |i| {
                    std.debug.print("{s} ", .{ghosts.items[i].name});
                }
                std.debug.print("\n", .{});
            }
            
            for (0..ghosts.items.len) |i| {
                if (directions[step % directions.len] == 'L') {
                    ghosts.items[i] = ghosts.items[i].*.L;
                } else if (directions[step % directions.len] == 'R') {
                    ghosts.items[i] = ghosts.items[i].*.R;
                } else {
                    std.debug.print("Invalid direction: {c}\n", .{directions[step]});
                    break;
                }
            }
            //std.debug.print("\n", .{});
            step = (step + 1);
        }
        std.debug.print("Final nodes:\n", .{});
        for (ghosts.items) |node| {
            std.debug.print("{s} ", .{node.name});
        }
        std.debug.print("\n\nPart two answer: All ghosts reached **Z in {d} steps\n", .{step});
        
    } // end if we got the line of directions

    
} // end of main 

pub fn numNodesEndInZ(nodes: *std.ArrayList(*const Node)) usize {
    var numZ: usize = 0;
    for (nodes.items) |node| {
        if (node.name[2] == 'Z') {
            numZ += 1;
        }
    }
    return numZ;
}