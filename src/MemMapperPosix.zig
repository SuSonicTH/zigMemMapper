const std = @import("std");

const parent = @import("MemMapper.zig");
const Options = parent.Options;
const MemMapperError = parent.MemMapperError;
const Super = parent.MemMapper;

pub const MemMapper = struct {
    file: std.fs.File = undefined,

    pub fn init(super: Super) !MemMapper {
        return .{
            .file = try std.fs.cwd().createFile(super.options.file_name, .{
                .read = true,
                .truncate = false,
                .exclusive = false,
            }),
        };
    }

    pub fn deinit(self: *MemMapper) void {
        self.file.close();
    }

    pub fn map(self: *MemMapper, comptime T: type, start: usize, len: usize) ![]T {
        var size = len;
        if (len == 0) {
            size = (try self.file.metadata()).size();
        }
        return @ptrCast(try std.posix.mmap(null, size, std.posix.PROT.READ, .{ .TYPE = .SHARED }, self.file.handle, start));
    }

    pub fn unmap(self: *MemMapper, memory: anytype) void {
        _ = self;
        std.posix.munmap(@alignCast(memory));
    }
};
