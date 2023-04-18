const std = @import("std");
const bt = struct {
    pub usingnamespace @import("../types.zig");
    pub usingnamespace @import("common.zig");
};

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const NodeStatus = bt.NodeStatus;

/// Basic methods implementing a Fallback node
pub fn FallbackNodeI(comptime Self: type) type {
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
                    .SUCCESS => return .SUCCESS,
                    .FAILURE => continue :tickloop,
                    else => return res,
                }
            }

            // All children have returned FAILURE
            return NodeStatus.FAILURE;
        }

        pub usingnamespace bt.ControlNodeI(Self);
    };
}

/// Simple Fallback node implementation
pub fn FallbackNode(comptime Ctx: type, comptime NodeReg: type, comptime Id: []const u8) type {
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

        pub usingnamespace FallbackNodeI(Self);
    };
}
