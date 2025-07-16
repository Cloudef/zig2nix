const std = @import("std");

export fn arc4random_stir() callconv(.c) void {
    // stub
}

export fn arc4random_addrandom(_: [*]const u8, _: c_int) callconv(.c) void {
    // stub
}

export fn arc4random() callconv(.c) u32 {
    return std.crypto.random.int(u32);
}

export fn arc4random_uniform(upper_bound: u32) callconv(.c) u32 {
    return std.crypto.random.uintLessThan(u32, upper_bound);
}

export fn arc4random_buf(buf: [*]u8, len: usize) callconv(.c) void {
    std.crypto.random.bytes(buf[0..len]);
}
