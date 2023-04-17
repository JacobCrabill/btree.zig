const std = @import("std");

const bt = @import("btree.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// Sample Context struct shared by all of our nodes
const Context = struct {
    foo: i32 = 0,
    bar: u32 = 0,
};

/// Dummy / example leaf node
const DummyNode = struct {
    const Self = @This();
    pub const ID = "dummy";
    context: *Context,
    name: []const u8,
    status: bt.NodeStatus = .IDLE,

    tickCount: usize = 0,

    // Create an instance of this Node type
    pub fn init(ctx: *Context, name: []const u8) Self {
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

/// Another sample Sequence node implementation
const SeqNode = struct {
    const Self = @This();
    pub const ID = "sequence_node";
    name: []const u8 = undefined,
    status: bt.NodeStatus = .IDLE,
    context: *Context = undefined,
    alloc: Allocator,
    children: ArrayList(*NodeReg),
    cur_idx: usize,

    pub fn init(alloc: Allocator, ctx: *Context, name: []const u8) Self {
        return .{
            .status = .IDLE,
            .alloc = alloc,
            .name = name,
            .context = ctx,
            .cur_idx = 0,
            .children = ArrayList(*NodeReg).init(alloc),
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

/// The NodeReg union is our registry of all available node types
const NodeReg = union(enum) {
    const Self = @This();
    foo: DummyNode,
    seq0: bt.SequenceNode(Context, NodeReg, "sequence"),
    seq1: SeqNode,
    leaf: NewLeaf,

    pub usingnamespace bt.RegistryMethods(Self);
};

test "Construct and tick a node" {
    var ctx = Context{};

    var foo = DummyNode.init(&ctx, "dummy");
    var foo2 = DummyNode.init(&ctx, "foonode");

    const res1 = foo.tick();
    const res2 = foo2.tick();

    std.debug.print("result: {}\n", .{res1});
    std.debug.print("result: {}\n", .{res2});
}

test "Build from Factory" {
    var ctx = Context{};
    var factory = bt.TreeFactory(NodeReg, Context).init(std.testing.allocator, &ctx);

    var new_node: NodeReg = try factory.build("dummy", "foo_instance");

    std.debug.print("Tick status: {any}\n", .{new_node.tick()});
    std.debug.print("We have a node of ID: {s}\n", .{new_node.getId()});
}

test "Build directly" {
    // Initialize a node directly using its "constructtor"
    var ctx = Context{};
    var seq0 = bt.SequenceNode(Context, NodeReg, "sequence").init(std.testing.allocator, &ctx, "sequence_0");
    _ = seq0.tick();
}

test "Sequence node" {
    var ctx = Context{};

    var factory = bt.TreeFactory(NodeReg, Context).init(std.testing.allocator, &ctx);

    // Initialize using the Factory
    var seq_node = try factory.build("sequence_node", "sequence_1");

    var leaf0: NodeReg = try factory.build("dummy", "leaf_0");
    var leaf1: NodeReg = try factory.build("dummy", "leaf_1");
    var leaf2: NodeReg = try factory.build("dummy", "leaf_1");

    var seq = seq_node.seq1;
    defer seq.deinit();

    try seq.addChild(&leaf0);
    try seq.addChild(&leaf1);
    try seq.addChild(&leaf2);

    std.debug.print("Ticking SequenceNode...\n", .{});
    while (seq.tick() == bt.NodeStatus.RUNNING) {}
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
    var factory = bt.TreeFactory(NodeReg, Context).init(std.testing.allocator, &ctx);

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
