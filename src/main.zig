const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// When ticked, a node may return RUNNING, SUCCESS, or FAILURE
const NodeStatus = enum(u3) {
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

// A generic behavior tree node type
pub fn Node(comptime Ctx: type, comptime Id: []const u8) type {
    return struct {
        const Self = @This();
        pub const ID: []const u8 = Id;
        context: *Ctx,
        name: []const u8,
        status: NodeStatus = .IDLE,

        // Create an instance of this Node type
        pub fn init(ctx: *Ctx, name: []const u8) Self {
            return Self{
                .context = ctx,
                .name = name,
            };
        }

        // Return the name of the Node type
        pub fn getId(_: Self) []const u8 {
            return ID;
        }

        // Use the mixin approach to add methods to our Node type
        pub usingnamespace NodeMethods(Self);
    };
}

const Context = struct {
    foo: i32 = 0,
    bar: u32 = 0,
};

const FooNode = Node(Context, "foo");
const RootNode = Node(Context, "root");

const NodeType = union(enum) {
    const Self = @This();
    foo: FooNode,
    root: RootNode,

    // Tick the specific node type which is active
    fn tick(self: *Self) NodeStatus {
        return switch (self.*) {
            inline else => |*node| node.tick(),
        };
    }

    fn getId(self: Self) []const u8 {
        return switch (self) {
            inline else => |*node| node.getId(),
        };
    }
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

        fn init(alloc: Allocator, context: *ctx) Self {
            return .{
                .alloc = alloc,
                .context = context,
            };
        }

        fn build(self: *Self, id: []const u8, name: []const u8) TreeFactoryError!RegTypes {
            // The fields of our union are the "registered" node types
            // We want to construct a NodeType which has the ID "id"
            const fields = std.meta.fields(RegTypes);
            inline for (fields) |field| {
                // If we've found the node type with the right ID, return it
                if (@hasDecl(field.type, "ID") and std.mem.eql(u8, field.type.ID, id)) {
                    if (!@hasField(field.type, "context")) {
                        return TreeFactoryError.BadNodeType;
                    }
                    return @unionInit(RegTypes, field.name, .{ .context = self.context, .name = name });
                }
            }

            return TreeFactoryError.IdNotFound;
        }
    };
}

test "Construct and tick a node" {
    var ctx = Context{};

    var root = RootNode.init(&ctx, "root");
    var foo = FooNode.init(&ctx, "foonode");

    const res1 = root.tick();
    const res2 = foo.tick();

    std.debug.print("result: {}\n", .{res1});
    std.debug.print("result: {}\n", .{res2});

    // Try making a list of Nodes...?
    var list = std.ArrayList(NodeType).init(std.testing.allocator);
    defer list.deinit();
    try list.append(NodeType{ .root = root });
    try list.append(NodeType{ .foo = foo });

    for (std.meta.declarations(@TypeOf(foo))) |decl| {
        std.debug.print("{s}, {any}\n", .{ decl.name, decl.is_pub });
    }
}

test "Factory build" {
    var ctx = Context{};
    var factory = TreeFactory(NodeType, Context).init(std.testing.allocator, &ctx);

    var new_node: NodeType = try factory.build("foo", "foo_instance");

    std.debug.print("Tick status: {any}\n", .{new_node.tick()});
    std.debug.print("We have a node of ID: {s}\n", .{new_node.getId()});
}
