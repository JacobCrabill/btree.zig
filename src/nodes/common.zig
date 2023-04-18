const std = @import("std");
const bt = @import("../types.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const NodeStatus = bt.NodeStatus;

/// Methods which apply generically to all Node types
pub fn NodeI(comptime Self: type) type {
    // Validate the given type
    const required_fields = [_][]const u8{"status"};
    const required_decls = [_][]const u8{ "ID", "getId", "tick" };
    inline for (required_fields) |field| if (!@hasField(Self, field))
        @compileError("Given Node type does not have the field:" ++ field);
    inline for (required_decls) |decl| if (!@hasDecl(Self, decl))
        @compileError("Given Node type does not have the decl:" ++ decl);

    return struct {
        // Get the Node's current status
        pub fn getStatus(self: *Self) NodeStatus {
            return self.status;
        }

        // Set the Node's current status
        pub fn setStatus(self: *Self, new_status: NodeStatus) void {
            self.status = new_status;
        }

        // Other methods generic to all Node types may go here
        // e.g. - Logging data or status updates
    };
}

/// Methods for a generic Control node
pub fn ControlNodeI(comptime Self: type) type {
    // Validate the given type
    const required_fields = [_][]const u8{"children"};
    inline for (required_fields) |field| if (!@hasField(Self, field))
        @compileError("Given Node type does not have the field:" ++ field);

    return struct {
        pub fn addChild(self: *Self, child: anytype) !void {
            try self.children.append(child);
        }

        pub fn deinit(self: *Self) void {
            self.children.deinit();
        }

        // Include all generic NodeI
        pub usingnamespace NodeI(Self);
    };
}

/// Methods for a Leaf node with state
pub fn StatefulNodeI(comptime Self: type) type {
    // Validate the given type
    const required_fields = [_][]const u8{"status"};
    const required_decls = [_][]const u8{ "onStart", "onRun" };
    inline for (required_fields) |field| if (!@hasField(Self, field))
        @compileError("Given Node type does not have the field:" ++ field);
    inline for (required_decls) |decl| if (!@hasDecl(Self, decl))
        @compileError("Given Node type does not have the decl:" ++ decl);

    return struct {
        // Tick the node, keeping track of its state
        pub fn tick(self: *Self) NodeStatus {
            var status = self.getStatus();

            if (status == .IDLE) {
                std.debug.print("StatefulNode::onStart()\n", .{});
                status = self.onStart();
            } else if (status == .RUNNING) {
                std.debug.print("StatefulNode::onRun()\n", .{});
                status = self.onRun();
            }

            self.setStatus(status);
            return status;
        }

        pub usingnamespace NodeI(Self);
    };
}
