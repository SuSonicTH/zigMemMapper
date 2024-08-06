const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
const ArrayList = std.ArrayList;

const CHAR = u8;
const LPCSTR = [*:0]const CHAR;
const DWORD = windows.DWORD;
const HANDLE = windows.HANDLE;
const SECURITY_ATTRIBUTES = windows.SECURITY_ATTRIBUTES;
const WINAPI = windows.WINAPI;
const SIZE_T = windows.SIZE_T;
const LPVOID = windows.LPVOID;
const LPCVOID = windows.LPCVOID;
const BOOL = windows.BOOL;
const LARGE_INTEGER = windows.LARGE_INTEGER;

const GENERIC_READ = windows.GENERIC_READ;
const GENERIC_WRITE = windows.GENERIC_WRITE;

const PAGE_READONLY = windows.PAGE_READONLY;
const PAGE_READWRITE = windows.PAGE_READWRITE;

const CREATE_NEW: DWORD = 1;
const CREATE_ALWAYS: DWORD = 2;
const OPEN_EXISTING: DWORD = 3;
const OPEN_ALWAYS: DWORD = 4;
const TRUNCATE_EXISTING: DWORD = 5;

const FILE_MAP_READ: DWORD = 4;
const FILE_MAP_WRITE: DWORD = 2;

const FILE_ATTRIBUTE_NORMAL = windows.FILE_ATTRIBUTE_NORMAL;

const INVALID_HANDLE_VALUE = windows.INVALID_HANDLE_VALUE;

extern "kernel32" fn CreateFileA(lpFileName: LPCSTR, dwDesiredAccess: DWORD, dwShareMode: DWORD, lpSecurityAttributes: ?*SECURITY_ATTRIBUTES, dwCreationDisposition: DWORD, dwFlagsAndAttributes: DWORD, hTemplateFil: ?HANDLE) callconv(WINAPI) HANDLE;
extern "kernel32" fn CreateFileMappingA(hFile: HANDLE, lpFileMappingAttributes: ?*SECURITY_ATTRIBUTES, flProtect: DWORD, dwMaximumSizeHigh: DWORD, dwMaximumSizeLow: DWORD, lpNam: ?LPCSTR) callconv(WINAPI) ?HANDLE;
extern "kernel32" fn MapViewOfFile(hFileMappingObject: HANDLE, dwDesiredAccess: DWORD, dwFileOffsetHigh: DWORD, dwFileOffsetLow: DWORD, dwNumberOfBytesToMa: SIZE_T) callconv(WINAPI) LPVOID;
extern "kernel32" fn UnmapViewOfFile(lpBaseAddress: LPCVOID) callconv(WINAPI) BOOL;

const CloseHandle = windows.kernel32.CloseHandle;
const GetFileSizeEx = windows.kernel32.GetFileSizeEx;

pub const Options = struct {
    file_name: [*:0]const u8,
    read: bool = true,
    write: bool = false,
    size: usize = 0,
};

const MemMapperError = error{
    CouldNotOpenFile,
    CouldNotMapFile,
};

pub fn init(allocator: std.mem.Allocator, options: Options) !MemMapper {
    return MemMapper.init(allocator, options);
}

const MemMapper = union(enum) {
    mem_mapper_windows: MemMapperWindows,
    mem_mapper_posix: MemMapperPosix,

    pub fn init(allocator: std.mem.Allocator, options: Options) !MemMapper {
        if (builtin.os.tag == .windows) {
            return .{
                .mem_mapper_windows = try MemMapperWindows.init(allocator, options),
            };
        } else {
            return .{
                .mem_mapper_posix = try MemMapperPosix.init(allocator, options),
            };
        }
    }

    pub fn deinit(self: *MemMapper) void {
        switch (self.*) {
            inline else => |*case| return case.deinit(),
        }
    }

    pub fn map(self: *MemMapper, comptime T: type, start: usize, len: usize) ?[]T {
        switch (self.*) {
            inline else => |*case| return case.map(T, start, len),
        }
    }

    pub fn unmap(self: *MemMapper, memory: anytype) void {
        switch (self.*) {
            inline else => |*case| return case.unmap(memory),
        }
    }
};

const MemMapperWindows = struct {
    allocator: std.mem.Allocator,
    options: Options,
    file: HANDLE,
    file_mapping: HANDLE,
    mappings: ArrayList(LPVOID),

    pub fn init(allocator: std.mem.Allocator, options: Options) !MemMapperWindows {
        var access: DWORD = 0;
        if (options.read) {
            access += GENERIC_READ;
        }
        if (options.write) {
            access += GENERIC_WRITE;
        }

        const file: HANDLE = CreateFileA(options.file_name, access, 0, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
        if (file == INVALID_HANDLE_VALUE) {
            return MemMapperError.CouldNotOpenFile;
        }
        errdefer _ = CloseHandle(file);

        var protection: DWORD = 0;
        if (options.write) {
            protection = PAGE_READWRITE;
        } else {
            protection = PAGE_READONLY;
        }

        const file_mapping = CreateFileMappingA(file, null, protection, 0, 0, null);
        if (file_mapping == null) {
            return MemMapperError.CouldNotMapFile;
        }

        return .{
            .allocator = allocator,
            .options = options,
            .file = file,
            .file_mapping = file_mapping.?,
            .mappings = ArrayList(LPVOID).init(allocator),
        };
    }

    pub fn deinit(self: *MemMapperWindows) void {
        _ = CloseHandle(self.file_mapping);
        _ = CloseHandle(self.file);
        self.mappings.deinit();
    }

    pub fn map(self: *MemMapperWindows, comptime T: type, start: usize, len: usize) ?[]T {
        //todo: use GetSystemInfo to get SYSTEM_INFO; Start offset must be a multiple of SYSTEM_INFO.dwAllocationGranularity
        const addr: [*]T = @ptrCast(MapViewOfFile(self.file_mapping, FILE_MAP_READ, 0, 0, len));
        var end: usize = start + len;
        if (len == 0) {
            var size: LARGE_INTEGER = @intCast(len);
            _ = GetFileSizeEx(self.file, &size);
            end = start + @as(usize, @intCast(size));
        }
        std.debug.print("{d},{d}\n", .{ start, end });
        return addr[0..end];
    }

    pub fn unmap(self: *MemMapperWindows, memory: anytype) void {
        _ = self;
        _ = UnmapViewOfFile(@constCast(std.mem.sliceAsBytes(memory).ptr));
    }
};

pub const MemMapperPosix = struct {
    allocator: std.mem.Allocator,
    options: Options,

    pub fn init(allocator: std.mem.Allocator, options: Options) !MemMapperPosix {
        return .{
            .allocator = allocator,
            .options = options,
        };
    }
    pub fn deinit(self: *MemMapperPosix) void {
        _ = self;
    }
    pub fn map(self: *MemMapperPosix, comptime T: type, start: usize, len: usize) ?[]T {
        _ = self;
        _ = start;
        _ = len;
        return null;
    }

    pub fn unmap(self: *MemMapperPosix, memory: anytype) void {
        _ = self;
        _ = memory;
    }
};

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    var mapper = try init(gpa, .{ .file_name = "test.txt" });
    defer mapper.deinit();

    const tst = mapper.map(u8, 0, 0).?;
    defer mapper.unmap(tst);

    std.debug.print(">{s}< {d}\n", .{ tst, tst.len });
}
