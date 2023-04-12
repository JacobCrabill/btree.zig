const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// When ticked, a node may return RUNNING, SUCCESS, or FAILURE
pub const NodeStatus = enum(u3) {
    RUNNING,
    SUCCESS,
    FAILURE,
    IDLE,
};

/// Methods which apply generically to all Node types
pub fn NodeMethods(comptime Self: type) type {
    const requried_fields = [_][]const u8{"status"};
    const requried_decls = [_][]const u8{ "ID", "getId" };
    inline for (requried_fields) |field| if (!@hasField(Self, field)) @compileError("Given Node type does not have the field:" ++ field);
    inline for (requried_decls) |decl| if (!@hasDecl(Self, decl)) @compileError("Given Node type does not have the decl:" ++ decl);

    return struct {
        // Get the Node's current status
        pub fn status(self: *Self) NodeStatus {
            return self.status;
        }

        // Tick the ndoe
        pub fn tick(self: *Self) NodeStatus {
            self.status = .SUCCESS;
            std.debug.print("[{s}][{s}] tick!\n{any}\n", .{ self.getId(), self.name, self.context });
            return .SUCCESS;
        }
    };
}

pub fn ControlNodeMethods(comptime Self: type) type {
    return struct {
        pub fn addChild(self: *Self, child: anytype) !void {
            try self.children.append(child);
        }

        pub fn deinit(self: *Self) void {
            self.children.deinit();
        }

        // Include all generic NodeMethods
        pub usingnamespace NodeMethods(Self);
    };
}
