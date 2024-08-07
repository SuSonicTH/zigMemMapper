const std = @import("std");
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

const parent = @import("MemMapper.zig");
const Options = parent.Options;
const MemMapperError = parent.MemMapperError;
const Super = parent.MemMapper;

pub const MemMapper = struct {
    file: HANDLE,
    file_mapping: HANDLE,
    mappings: ArrayList(LPVOID),

    pub fn init(super: Super) !MemMapper {
        var access: DWORD = 0;
        if (super.options.read) {
            access += GENERIC_READ;
        }
        if (super.options.write) {
            access += GENERIC_WRITE;
        }

        const file: HANDLE = CreateFileA(super.options.file_name, access, 0, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
        if (file == INVALID_HANDLE_VALUE) {
            return MemMapperError.CouldNotOpenFile;
        }
        errdefer _ = CloseHandle(file);

        var protection: DWORD = 0;
        if (super.options.write) {
            protection = PAGE_READWRITE;
        } else {
            protection = PAGE_READONLY;
        }

        const file_mapping = CreateFileMappingA(file, null, protection, 0, 0, null);
        if (file_mapping == null) {
            return MemMapperError.CouldNotMapFile;
        }

        return .{
            .file = file,
            .file_mapping = file_mapping.?,
            .mappings = ArrayList(LPVOID).init(super.allocator),
        };
    }

    pub fn deinit(self: *MemMapper) void {
        _ = CloseHandle(self.file_mapping);
        _ = CloseHandle(self.file);
        self.mappings.deinit();
    }

    pub fn map(self: *MemMapper, comptime T: type, start: usize, len: usize) ?[]T {
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

    pub fn unmap(self: *MemMapper, memory: anytype) void {
        _ = self;
        _ = UnmapViewOfFile(@constCast(std.mem.sliceAsBytes(memory).ptr));
    }
};
