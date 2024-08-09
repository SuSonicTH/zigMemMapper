const std = @import("std");
const builtin = @import("builtin");

pub const Options = struct {
    file_name: []const u8,
    read: bool = true,
    write: bool = false,
    size: usize = 0,
};

pub const MemMapperError = error{
    CouldNotOpenFile,
    CouldNotMapFile,
};

const MemMpperImpl = switch (builtin.os.tag) {
    .windows => @import("MemMapperWindows.zig").MemMapper,
    else => @import("MemMapperPosix.zig").MemMapper,
};

pub fn init(options: Options) !MemMapper {
    return MemMapper.init(options);
}

pub const MemMapper = struct {
    impl: MemMpperImpl = undefined,
    options: Options,

    pub fn init(options: Options) !MemMapper {
        var this: MemMapper = .{
            .options = options,
        };
        this.impl = (try MemMpperImpl.init(this));
        return this;
    }

    pub fn deinit(self: *MemMapper) void {
        self.impl.deinit();
    }

    pub fn map(self: *MemMapper, comptime T: type, start: usize, len: usize) ![]T {
        return self.impl.map(T, start, len);
    }

    pub fn unmap(self: *MemMapper, memory: anytype) void {
        self.impl.unmap(memory);
    }
};

const testing = std.testing;

test "simple mapping for reading" {
    var mapper = try init(.{ .file_name = "test.txt" });
    defer mapper.deinit();

    const tst = try mapper.map(u8, 0, 0);
    defer mapper.unmap(tst);

    try testing.expectEqualStrings("This is a Test", tst);
    try testing.expectEqual(14, tst.len);
}
