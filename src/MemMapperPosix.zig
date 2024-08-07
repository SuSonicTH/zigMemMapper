const std = @import("std");

const parent = @import("MemMapper.zig");
const Options = parent.Options;
const MemMapperError = parent.MemMapperError;
const Super = parent.MemMapper;

pub const MemMapper = struct {
    pub fn init(super: Super) !MemMapper {
        _ = super;
        return .{};
    }
    pub fn deinit(self: *MemMapper) void {
        _ = self;
    }
    pub fn map(self: *MemMapper, comptime T: type, start: usize, len: usize) ?[]T {
        _ = self;
        _ = start;
        _ = len;
        return null;
    }

    pub fn unmap(self: *MemMapper, memory: anytype) void {
        _ = self;
        _ = memory;
    }
};
