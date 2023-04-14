const std = @import("std");

const bt = @import("btree.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// TODO: This is the wrong way to make an impl. Redo.
// A generic behavior tree node type
pub fn Node(comptime Ctx: type, comptime Id: []const u8) type {
    return struct {
        const Self = @This();
        pub const ID: []const u8 = Id;
        context: *Ctx,
        name: []const u8,
        status: bt.NodeStatus = .IDLE,

        tickCount: usize = 0,

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

        pub fn tick(self: *Self) bt.NodeStatus {
            self.status = .RUNNING;
            if (self.tickCount > 2) {
                self.status = .SUCCESS;
            }

            std.debug.print("[{s}][{s}] ", .{ self.getId(), self.name });
            std.debug.print("tick -> {any}!\n", .{self.getStatus()});

            self.tickCount += 1;
            return self.status;
        }

        // Use the mixin approach to add methods to our Node type
        pub usingnamespace bt.NodeI(Self);
    };
}

pub fn SequenceNode(comptime Ctx: type, comptime Id: []const u8) type {
    return struct {
        const Self = @This();
        pub const ID: []const u8 = Id;
        context: *Ctx,
        name: []const u8,
        status: bt.NodeStatus = .IDLE,
        children: ArrayList(*NodeType),
        cur_idx: usize,

        pub fn init(alloc: Allocator, context: *Ctx, name: []const u8) Self {
            return Self{
                .context = context,
                .name = name,
                .cur_idx = 0,
                .children = ArrayList(*NodeType).init(alloc),
            };
        }

        // Return the name of the Node type
        pub fn getId(_: Self) []const u8 {
            return ID;
        }

        pub fn tick(self: *Self) bt.NodeStatus {
            return self.tickChildren();
        }

        pub usingnamespace bt.SequenceNodeI(Self);
    };
}

const SeqNode = struct {
    const Self = @This();
    pub const ID = "sequence_node";
    name: []const u8 = undefined,
    status: bt.NodeStatus = .IDLE,
    context: *Context = undefined,
    alloc: Allocator,
    children: ArrayList(*NodeType),
    cur_idx: usize,

    pub fn init(alloc: Allocator, ctx: *Context, name: []const u8) Self {
        return .{
            .status = .IDLE,
            .alloc = alloc,
            .name = name,
            .context = ctx,
            .cur_idx = 0,
            .children = ArrayList(*NodeType).init(alloc),
        };
    }

    pub fn getId(_: Self) []const u8 {
        return ID;
    }

    pub fn tick(self: *Self) bt.NodeStatus {
        return self.tickChildren();
    }

    pub usingnamespace bt.SequenceNodeI(Self);
};

const Context = struct {
    foo: i32 = 0,
    bar: u32 = 0,
};

const FooNode = Node(Context, "foo");
const RootNode = Node(Context, "root");
const Sequence = SequenceNode(Context, "sequence");

/// The NodeType union is our registry of all available node types
const NodeType = union(enum) {
    const Self = @This();
    foo: FooNode,
    root: RootNode,
    seq: Sequence,
    seq1: SeqNode,
    leaf: NewLeaf,

    // Tick the specific node type which is active
    pub fn tick(self: *Self) bt.NodeStatus {
        return switch (self.*) {
            inline else => |*node| node.tick(),
        };
    }

    pub fn getId(self: Self) []const u8 {
        return switch (self) {
            inline else => |*node| node.getId(),
        };
    }
};

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

test "Build from Factory" {
    var ctx = Context{};
    var factory = bt.TreeFactory(NodeType, Context).init(std.testing.allocator, &ctx);

    var new_node: NodeType = try factory.build("foo", "foo_instance");

    std.debug.print("Tick status: {any}\n", .{new_node.tick()});
    std.debug.print("We have a node of ID: {s}\n", .{new_node.getId()});
}

test "Build directly" {
    // Initialize a node directly using its "constructtor"
    var ctx = Context{};
    var seq0 = SequenceNode(Context, "sequence").init(std.testing.allocator, &ctx, "sequence_0");
    _ = seq0.tick();
}

test "Sequence node" {
    std.debug.print("\n---- Testing basic SequenceNode ----\n", .{});
    var ctx = Context{};

    var factory = bt.TreeFactory(NodeType, Context).init(std.testing.allocator, &ctx);

    // Initialize using the Factory
    var seq_node = try factory.build("sequence_node", "sequence_1");

    var leaf0: NodeType = try factory.build("foo", "leaf_0");
    var leaf1: NodeType = try factory.build("foo", "leaf_1");
    var leaf2: NodeType = try factory.build("foo", "leaf_1");

    var seq = seq_node.seq1;
    defer seq.deinit();

    try seq.addChild(&leaf0);
    try seq.addChild(&leaf1);
    try seq.addChild(&leaf2);

    std.debug.print("Ticking SequenceNode...\n", .{});
    while (seq.tick() == bt.NodeStatus.RUNNING) {
        std.debug.print("----\n", .{});
    }
    std.debug.print("---- Success ----\n", .{});
}

const NewLeaf = struct {
    pub const Self = @This();
    pub const ID = "new_leaf";
    context: *Context,
    name: []const u8 = undefined,
    status: bt.NodeStatus = .IDLE,

    count: usize = 0,

    pub fn getId(_: Self) []const u8 {
        return ID;
    }

    pub fn onStart(self: *Self) bt.NodeStatus {
        self.count = 1;
        return .RUNNING;
    }

    pub fn onRun(self: *Self) bt.NodeStatus {
        if (self.count > 2)
            return .SUCCESS;

        self.count += 1;
        return .RUNNING;
    }

    pub usingnamespace bt.StatefulNodeI(Self);
};

test "Stateful Leaf Node" {
    var ctx = Context{};
    var factory = bt.TreeFactory(NodeType, Context).init(std.testing.allocator, &ctx);

    var leaf_node = try factory.build("new_leaf", "foo_leaf");

    var leaf: NewLeaf = leaf_node.leaf;

    while (leaf.tick() == .RUNNING) {}
}

// ----------------------- Tests on 'usingnamespace' -----------------------

pub fn AIface(comptime Self: type) type {
    return struct {
        foo_: usize = 1,

        pub fn foo(self: *Self) *usize {
            return &(self.foo_);
        }
    };
}

const B = struct {
    const Self = @This();

    foo_: usize = 1,

    pub fn hello(self: *Self) void {
        std.debug.print("Foo 1: {d}\n", .{self.foo().*});
        var c = self.foo();
        c.* = 2;
        std.debug.print("Foo 2: {d}\n", .{self.foo().*});
    }

    usingnamespace AIface(Self);
};

test "usingnamespace" {
    var b = B{};

    b.hello();
}
