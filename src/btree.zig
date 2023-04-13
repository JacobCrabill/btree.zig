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

const TreeFactoryError = error{
    IdNotFound,
    BadNodeType,
};

pub fn isValidNodeType(node: type) bool {
    if (!@hasField(node, "name") or @hasField(node, "context") or !@hasDecl(node, "ID"))
        return false;

    return true;
}

pub fn TreeFactory(comptime node_types: type, comptime ctx: type) type {
    return struct {
        const Self = @This();
        const RegTypes = node_types;
        const Context = ctx;
        alloc: std.mem.Allocator,
        context: *ctx,

        pub fn init(alloc: Allocator, context: *ctx) Self {
            return .{
                .alloc = alloc,
                .context = context,
            };
        }

        pub fn build(self: *Self, alloc: Allocator, id: []const u8, name: []const u8) TreeFactoryError!RegTypes {
            // The fields of our union are the "registered" node types
            // We want to construct a NodeType which has the ID "id"
            const fields = std.meta.fields(RegTypes);
            inline for (fields) |field| {
                // If we've found the node type with the right ID, return it
                if (@hasDecl(field.type, "ID") and std.mem.eql(u8, field.type.ID, id)) {
                    if (!@hasField(field.type, "context")) {
                        return TreeFactoryError.BadNodeType;
                    }

                    if (@hasField(field.type, "children")) {
                        if (!@hasDecl(field.type, "init"))
                            @compileError("type " ++ field.name ++ " does not have method 'init'");

                        var ctrl = field.type.init(alloc, self.context, name);
                        return @unionInit(RegTypes, field.name, ctrl);
                    } else {
                        return @unionInit(RegTypes, field.name, .{ .context = self.context, .name = name });
                    }
                }
            }

            return TreeFactoryError.IdNotFound;
        }
    };
}

/// Methods which apply generically to all Node types
pub fn NodeMethods(comptime Self: type) type {
    // Validate the given type
    const requried_fields = [_][]const u8{"status"};
    const requried_decls = [_][]const u8{ "ID", "getId", "tick" };
    inline for (requried_fields) |field| if (!@hasField(Self, field)) @compileError("Given Node type does not have the field:" ++ field);
    inline for (requried_decls) |decl| if (!@hasDecl(Self, decl)) @compileError("Given Node type does not have the decl:" ++ decl);

    return struct {
        // Get the Node's current status
        pub fn getStatus(self: *Self) NodeStatus {
            return self.status;
        }

        // Other methods generic to all Node types may go here
        // e.g. - Logging data or status updates
    };
}

pub fn ControlNodeI(comptime Self: type) type {
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

pub fn SequenceNodeI(comptime Self: type) type {
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
