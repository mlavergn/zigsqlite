const std = @import("std");

pub const Demo = @import("demo.zig").Demo;

// -----------------------------------------------------------------------------
// Unit Tests

test {
    std.testing.refAllDecls(@This());
}
