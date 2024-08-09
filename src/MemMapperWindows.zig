const std = @import("std");

const parent = @import("MemMapper.zig");
const Options = parent.Options;
const MemMapperError = parent.MemMapperError;
const Super = parent.MemMapper;

pub const MemMapper = struct {
    file: std.fs.File,
    file_mapping: HANDLE,

    pub fn init(super: Super) !MemMapper {
        const file = try std.fs.cwd().createFile(super.options.file_name, .{
            .read = true,
            .truncate = false,
            .exclusive = false,
        });
        var protection: DWORD = 0;
        if (super.options.write) {
            protection = PAGE_READWRITE;
        } else {
            protection = PAGE_READONLY;
        }

        const file_mapping = CreateFileMappingA(file.handle, null, protection, 0, 0, null);
        if (file_mapping == null) {
            return MemMapperError.CouldNotMapFile;
        }

        return .{
            .file = file,
            .file_mapping = file_mapping.?,
        };
    }

    pub fn deinit(self: *MemMapper) void {
        _ = CloseHandle(self.file_mapping);
        self.file.close();
    }

    pub fn map(self: *MemMapper, comptime T: type, start: usize, len: usize) ![]T {
        //todo: use GetSystemInfo to get SYSTEM_INFO; Start offset must be a multiple of SYSTEM_INFO.dwAllocationGranularity
        const addr: [*]T = @ptrCast(MapViewOfFile(self.file_mapping, FILE_MAP_READ, 0, 0, len));
        var end: usize = start + len;
        if (len == 0) {
            end = (try self.file.metadata()).size();
        }
        return addr[0..end];
    }

    pub fn unmap(self: *MemMapper, memory: anytype) void {
        _ = self;
        _ = UnmapViewOfFile(@constCast(std.mem.sliceAsBytes(memory).ptr));
    }
};

const windows = std.os.windows;

const CHAR = u8;
const LPCSTR = [*:0]const CHAR;
const DWORD = windows.DWORD;
const HANDLE = windows.HANDLE;
const SECURITY_ATTRIBUTES = windows.SECURITY_ATTRIBUTES;
const SIZE_T = windows.SIZE_T;
const LPVOID = windows.LPVOID;
const LPCVOID = windows.LPCVOID;
const BOOL = windows.BOOL;

const WINAPI = windows.WINAPI;

const PAGE_READONLY = windows.PAGE_READONLY;
const PAGE_READWRITE = windows.PAGE_READWRITE;

const CREATE_NEW: DWORD = 1;
const CREATE_ALWAYS: DWORD = 2;
const OPEN_EXISTING: DWORD = 3;
const OPEN_ALWAYS: DWORD = 4;
const TRUNCATE_EXISTING: DWORD = 5;

const FILE_MAP_READ: DWORD = 4;
const FILE_MAP_WRITE: DWORD = 2;

extern "kernel32" fn CreateFileMappingA(hFile: HANDLE, lpFileMappingAttributes: ?*SECURITY_ATTRIBUTES, flProtect: DWORD, dwMaximumSizeHigh: DWORD, dwMaximumSizeLow: DWORD, lpNam: ?LPCSTR) callconv(WINAPI) ?HANDLE;
extern "kernel32" fn MapViewOfFile(hFileMappingObject: HANDLE, dwDesiredAccess: DWORD, dwFileOffsetHigh: DWORD, dwFileOffsetLow: DWORD, dwNumberOfBytesToMa: SIZE_T) callconv(WINAPI) LPVOID;
extern "kernel32" fn UnmapViewOfFile(lpBaseAddress: LPCVOID) callconv(WINAPI) BOOL;

const CloseHandle = windows.kernel32.CloseHandle;
