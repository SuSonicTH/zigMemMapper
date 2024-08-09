const std = @import("std");

pub const MemMapper = struct {
    file: std.fs.File,
    pub fn init(file: std.fs.File, writeable: bool) !MemMapper {
        _ = writeable;
        return .{
            .file = file,
        };
    }

    pub fn deinit(self: *MemMapper) void {
        _ = self;
    }

    pub fn map(self: *MemMapper, comptime T: type, offset: usize, size: usize) ![]T {
        const len = if (size != 0) size else (try self.file.metadata()).size();
        return @ptrCast(try std.posix.mmap(null, len, std.posix.PROT.READ, .{ .TYPE = .SHARED }, self.file.handle, offset));
    }

    pub fn unmap(self: *MemMapper, memory: anytype) void {
        _ = self;
        std.posix.munmap(@alignCast(memory));
    }
};
