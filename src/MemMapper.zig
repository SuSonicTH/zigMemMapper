const std = @import("std");
const builtin = @import("builtin");

pub const MemMapperError = error{
    CouldNotMapFile,
    CouldNotMapRegion,
};

pub const Options = struct {
    read: bool = true,
    write: bool = false,
    offset: usize = 0,
    size: usize = 0,
};

pub fn init(file: std.fs.File, writeable: bool) !MemMapper {
    return MemMapper.init(file, writeable);
}

const MemMapper = struct {
    file: std.fs.File,
    file_mapping: windows.HANDLE = undefined,

    pub fn init(file: std.fs.File, writeable: bool) !MemMapper {
        if (builtin.os.tag == .windows) {
            const protection: windows.DWORD = if (writeable) windows.PAGE_READWRITE else windows.PAGE_READONLY;
            const file_mapping = CreateFileMappingA(file.handle, null, protection, 0, 0, null);
            if (file_mapping == null) {
                return MemMapperError.CouldNotMapFile;
            }

            return .{
                .file = file,
                .file_mapping = file_mapping.?,
            };
        } else {
            return .{
                .file = file,
            };
        }
    }

    pub fn deinit(self: *MemMapper) void {
        if (builtin.os.tag == .windows) {
            _ = CloseHandle(self.file_mapping);
        }
    }

    pub fn map(self: *MemMapper, comptime T: type, options: Options) ![]T {
        const len = if (options.size != 0) options.size else (try self.file.metadata()).size();

        if (builtin.os.tag == .windows) {
            var access: windows.DWORD = 0;
            if (options.read) access |= FILE_MAP_READ;
            if (options.write) access |= FILE_MAP_WRITE;

            const ptr = MapViewOfFile(self.file_mapping, FILE_MAP_READ, 0, 0, len);
            if (ptr == null) {
                return MemMapperError.CouldNotMapRegion;
            }
            return @as([*]T, @ptrCast(ptr))[0..len];
        } else {
            var prot: u32 = 0;
            if (options.read) prot |= std.posix.PROT.READ;
            if (options.write) prot |= std.posix.PROT.WRITE;

            return @ptrCast(try std.posix.mmap(null, len, prot, .{ .TYPE = .SHARED }, self.file.handle, options.offset));
        }
    }

    pub fn unmap(self: *MemMapper, memory: anytype) void {
        _ = self;
        if (builtin.os.tag == .windows) {
            _ = UnmapViewOfFile(@constCast(std.mem.sliceAsBytes(memory).ptr));
        } else {
            std.posix.munmap(@alignCast(memory));
        }
    }
};

const windows = std.os.windows;

const FILE_MAP_READ: windows.DWORD = 4;
const FILE_MAP_WRITE: windows.DWORD = 2;

extern "kernel32" fn CreateFileMappingA(hFile: windows.HANDLE, lpFileMappingAttributes: ?*windows.SECURITY_ATTRIBUTES, flProtect: windows.DWORD, dwMaximumSizeHigh: windows.DWORD, dwMaximumSizeLow: windows.DWORD, lpNam: ?windows.LPCSTR) callconv(windows.WINAPI) ?windows.HANDLE;
extern "kernel32" fn MapViewOfFile(hFileMappingObject: windows.HANDLE, dwDesiredAccess: windows.DWORD, dwFileOffsetHigh: windows.DWORD, dwFileOffsetLow: windows.DWORD, dwNumberOfBytesToMa: windows.SIZE_T) callconv(windows.WINAPI) ?windows.LPVOID;
extern "kernel32" fn UnmapViewOfFile(lpBaseAddress: windows.LPCVOID) callconv(windows.WINAPI) windows.BOOL;

const CloseHandle = windows.kernel32.CloseHandle;

const testing = std.testing;

test "simple mapping for reading" {
    const file = try std.fs.cwd().createFile("test.txt", .{
        .read = true,
        .truncate = false,
        .exclusive = false,
    });
    var mapper = try init(file, false);
    defer mapper.deinit();

    const tst = try mapper.map(u8, .{});
    defer mapper.unmap(tst);

    try testing.expectEqualStrings("This is a Test", tst);
    try testing.expectEqual(14, tst.len);
}
