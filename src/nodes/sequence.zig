const std = @import("std");
const bt = @import("../types.zig");
const nodes = @import("../nodes.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const NodeStatus = bt.NodeStatus;

/// Basic methods implementing a Sequence node
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

        pub usingnamespace nodes.ControlNodeI(Self);
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
