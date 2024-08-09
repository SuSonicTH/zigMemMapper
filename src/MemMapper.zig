const std = @import("std");
const builtin = @import("builtin");

pub const MemMapperError = error{
    CouldNotMapFile,
};

const MemMpperImpl = switch (builtin.os.tag) {
    .windows => @import("MemMapperWindows.zig").MemMapper,
    else => @import("MemMapperPosix.zig").MemMapper,
};

pub fn init(file: std.fs.File, writeable: bool) !MemMapper {
    return MemMapper.init(file, writeable);
}

pub const MemMapper = struct {
    impl: MemMpperImpl = undefined,

    pub fn init(file: std.fs.File, writeable: bool) !MemMapper {
        return .{
            .impl = (try MemMpperImpl.init(file, writeable)),
        };
    }

    pub fn deinit(self: *MemMapper) void {
        self.impl.deinit();
    }

    pub fn map(self: *MemMapper, comptime T: type, offset: usize, size: usize) ![]T {
        return self.impl.map(T, offset, size);
    }

    pub fn unmap(self: *MemMapper, memory: anytype) void {
        self.impl.unmap(memory);
    }
};

const testing = std.testing;

test "simple mapping for reading" {
    const file = try std.fs.cwd().createFile("test.txt", .{
        .read = true,
        .truncate = false,
        .exclusive = false,
    });
    var mapper = try init(file, false);
    defer mapper.deinit();

    const tst = try mapper.map(u8, 0, 0);
    defer mapper.unmap(tst);

    try testing.expectEqualStrings("This is a Test", tst);
    try testing.expectEqual(14, tst.len);
}
