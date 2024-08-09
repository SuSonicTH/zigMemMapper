const std = @import("std");

const parent = @import("MemMapper.zig");
const MemMapperError = parent.MemMapperError;

pub const MemMapper = struct {
    file: std.fs.File,
    file_mapping: windows.HANDLE,

    pub fn init(file: std.fs.File, writeable: bool) !MemMapper {
        const protection: windows.DWORD = if (writeable) windows.PAGE_READWRITE else windows.PAGE_READONLY;
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
    }

    pub fn map(self: *MemMapper, comptime T: type, offset: usize, size: usize) ![]T {
        //todo: use GetSystemInfo to get SYSTEM_INFO; Start offset must be a multiple of SYSTEM_INFO.dwAllocationGranularity
        _ = offset;
        const len = if (size != 0) size else (try self.file.metadata()).size();
        const ptr: [*]T = @ptrCast(MapViewOfFile(self.file_mapping, FILE_MAP_READ, 0, 0, len));
        return ptr[0..len];
    }

    pub fn unmap(self: *MemMapper, memory: anytype) void {
        _ = self;
        _ = UnmapViewOfFile(@constCast(std.mem.sliceAsBytes(memory).ptr));
    }
};

const windows = std.os.windows;

const FILE_MAP_READ: windows.DWORD = 4;
const FILE_MAP_WRITE: windows.DWORD = 2;

extern "kernel32" fn CreateFileMappingA(hFile: windows.HANDLE, lpFileMappingAttributes: ?*windows.SECURITY_ATTRIBUTES, flProtect: windows.DWORD, dwMaximumSizeHigh: windows.DWORD, dwMaximumSizeLow: windows.DWORD, lpNam: ?windows.LPCSTR) callconv(windows.WINAPI) ?windows.HANDLE;
extern "kernel32" fn MapViewOfFile(hFileMappingObject: windows.HANDLE, dwDesiredAccess: windows.DWORD, dwFileOffsetHigh: windows.DWORD, dwFileOffsetLow: windows.DWORD, dwNumberOfBytesToMa: windows.SIZE_T) callconv(windows.WINAPI) windows.LPVOID;
extern "kernel32" fn UnmapViewOfFile(lpBaseAddress: windows.LPCVOID) callconv(windows.WINAPI) windows.BOOL;

const CloseHandle = windows.kernel32.CloseHandle;
