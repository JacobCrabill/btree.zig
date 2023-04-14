// When ticked, a node may return RUNNING, SUCCESS, or FAILURE
pub const NodeStatus = enum(u3) {
    RUNNING,
    SUCCESS,
    FAILURE,
    IDLE,
};

// Error union for the TreeFactory
pub const TreeFactoryError = error{
    IdNotFound,
    BadNodeType,
};
