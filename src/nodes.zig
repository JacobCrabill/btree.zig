const std = @import("std");
const bt = @import("types.zig");

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

pub fn SequenceNodeI(comptime Self: type) type {
    // Validate the given type
    const required_fields = [_][]const u8{ "children", "cur_idx" };
    inline for (required_fields) |field| if (!@hasField(Self, field))
        @compileError("Given Node type does not have the field:" ++ field);

    return struct {
        pub fn tickChildren(self: *Self) NodeStatus {
            const nchild = self.children.items.len;
            tickloop: while (self.cur_idx < nchild) : (self.cur_idx += 1) {
                const res: NodeStatus = self.children.items[self.cur_idx].tick();
                switch (res) {
                    .SUCCESS => continue :tickloop,
                    .FAILURE => return .FAILURE,
                    else => return res,
                }
            }

            // All children have returned SUCCESS
            return NodeStatus.SUCCESS;
        }

        pub usingnamespace ControlNodeI(Self);
    };
}

/// Methods for a leaf node with state
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

/// Simple Sequence node implementation
pub fn SequenceNode(comptime Ctx: type, comptime NodeReg: type, comptime Id: []const u8) type {
    return struct {
        const Self = @This();
        pub const ID: []const u8 = Id;
        context: *Ctx,
        name: []const u8,
        status: bt.NodeStatus = .IDLE,
        children: ArrayList(*NodeReg),
        cur_idx: usize,

        pub fn init(alloc: Allocator, context: *Ctx, name: []const u8) Self {
            return Self{
                .context = context,
                .name = name,
                .cur_idx = 0,
                .children = ArrayList(*NodeReg).init(alloc),
            };
        }

        // Return the name of the Node type
        pub fn getId(_: Self) []const u8 {
            return ID;
        }

        pub fn tick(self: *Self) bt.NodeStatus {
            return self.tickChildren();
        }

        pub usingnamespace SequenceNodeI(Self);
    };
}
