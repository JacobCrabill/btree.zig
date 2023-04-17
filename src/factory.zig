const std = @import("std");
const bt = @import("types.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const TreeFactoryError = bt.TreeFactoryError;

pub fn isControlNode(comptime node: type) bool {
    return @hasField(node, "children");
}

pub fn isValidNodeType(comptime node: type) bool {
    if (!@hasField(node, "name") or @hasField(node, "context") or !@hasDecl(node, "ID"))
        return false;

    return true;
}

/// Methods applicable to the node-registry union
pub fn RegistryMethods(comptime T: type) type {
    return struct {
        // Tick the specific node type which is active
        pub fn tick(self: *T) bt.NodeStatus {
            return switch (self.*) {
                inline else => |*node| node.tick(),
            };
        }

        // Get the ID of the active type
        pub fn getId(self: T) []const u8 {
            return switch (self) {
                inline else => |*node| node.getId(),
            };
        }
    };
}

/// Factory for building tree nodes from a node registry
pub fn TreeFactory(comptime registration: type, comptime ctx: type) type {
    return struct {
        const Self = @This();
        const RegTypes = registration;
        const Context = ctx;
        alloc: std.mem.Allocator,
        context: *ctx,

        pub fn init(alloc: Allocator, context: *ctx) Self {
            return .{
                .alloc = alloc,
                .context = context,
            };
        }

        pub fn build(self: *Self, id: []const u8, name: []const u8) TreeFactoryError!RegTypes {
            // The fields of our union are the "registered" node types
            // We want to construct a NodeType which has the ID "id"
            const fields = std.meta.fields(RegTypes);
            inline for (fields) |field| {
                const node = field.type;

                // If we've found the node type with the right ID, return it
                if (@hasDecl(node, "ID") and std.mem.eql(u8, node.ID, id)) {
                    if (!@hasField(node, "context")) {
                        return TreeFactoryError.BadNodeType;
                    }

                    // TODO: add a NodeType(?) enum for Leaf, Control, Modifier
                    //if (isControlNode(node)) {
                    if (@hasField(node, "children")) {
                        if (!@hasDecl(node, "init"))
                            @compileError("type " ++ field.name ++ " does not have method 'init'");

                        var ctrl = node.init(self.alloc, self.context, name);
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
