//! Windows API bindings for UI Automation
//!
//! This module provides Zig bindings for Windows COM types and UI Automation APIs.
//! Only compiles on Windows platform.

const std = @import("std");
const builtin = @import("builtin");
const zigwin32 = @import("zigwin32");

pub const UIA_IDs = @import("./windows_uia_ids.zig");

// ============================================================================
// Calling Convention
// ============================================================================

/// The C calling convention for the target platform
pub const cc: std.builtin.CallingConvention = std.builtin.CallingConvention.c;

// ============================================================================
// Basic Windows Types
// ============================================================================

pub const HRESULT = i32;
pub const BOOL = i32;
pub const LONG = i32;
pub const ULONG = u32;
pub const DWORD = u32;
pub const WORD = u16;
pub const BYTE = u8;
pub const UINT = u32;
pub const INT = i32;
pub const WCHAR = u16;
pub const LPWSTR = [*:0]WCHAR;
pub const LPCWSTR = [*:0]const WCHAR;
pub const BSTR = ?[*:0]WCHAR;
pub const LPVOID = *anyopaque;
pub const WPARAM = usize;
pub const LPARAM = isize;
pub const LRESULT = isize;

pub const HWND = zigwin32.foundation.HWND;
pub const HINSTANCE = *opaque {};
pub const HMODULE = HINSTANCE; // HMODULE is alias for HINSTANCE
pub const ATOM = WORD;
pub const HCURSOR = *opaque {};
pub const HBRUSH = *opaque {};
pub const HICON = *opaque {};
pub const HMENU = *opaque {};

pub const IDC_ARROW: LPCWSTR = @ptrFromInt(32512);
pub const COLOR_WINDOW: *opaque {} = @ptrFromInt(5);

pub const PM_NOREMOVE: UINT = 0x0000;
pub const PM_REMOVE: UINT = 0x0001;
pub const PM_NOYIELD: UINT = 0x0002;

// ============================================================================
// COM Types
// ============================================================================

pub const GUID = extern struct {
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,

    pub fn eql(self: *const GUID, other: *const GUID) bool {
        return self.Data1 == other.Data1 and
            self.Data2 == other.Data2 and
            self.Data3 == other.Data3 and
            std.mem.eql(u8, &self.Data4, &other.Data4);
    }
    pub fn asString(self: *const GUID) []const u8 {
        return std.fmt.allocPrint(std.heap.page_allocator, "{x:08}-{x:04}-{x:04}-{x:02}{x:02}-{x:02}{x:02}{x:02}{x:02}{x:02}{x:02}", .{ self.Data1, self.Data2, self.Data3, self.Data4[0], self.Data4[1], self.Data4[2], self.Data4[3], self.Data4[4], self.Data4[5], self.Data4[6], self.Data4[7] }) catch "invalid-guid";
    }
};

pub const IID = GUID;
pub const REFIID = *const IID;

// ============================================================================
// HRESULT Values
// ============================================================================

pub const S_OK: HRESULT = 0;
pub const S_FALSE: HRESULT = 1;
pub const E_NOTIMPL: HRESULT = @bitCast(@as(u32, 0x80004001));
pub const E_NOINTERFACE: HRESULT = @bitCast(@as(u32, 0x80004002));
pub const E_POINTER: HRESULT = @bitCast(@as(u32, 0x80004003));
pub const E_FAIL: HRESULT = @bitCast(@as(u32, 0x80004005));
pub const E_INVALIDARG: HRESULT = @bitCast(@as(u32, 0x80070057));
pub const E_OUTOFMEMORY: HRESULT = @bitCast(@as(u32, 0x8007000E));

pub fn SUCCEEDED(hr: HRESULT) bool {
    return hr >= 0;
}

pub fn FAILED(hr: HRESULT) bool {
    return hr < 0;
}

// ============================================================================
// VARIANT Types
// ============================================================================

pub const VARENUM = enum(WORD) { VT_EMPTY = 0, VT_NULL = 1, VT_I2 = 2, VT_I4 = 3, VT_R4 = 4, VT_R8 = 5, VT_CY = 6, VT_DATE = 7, VT_BSTR = 8, VT_DISPATCH = 9, VT_ERROR = 10, VT_BOOL = 11, VT_VARIANT = 12, VT_UNKNOWN = 13, VT_DECIMAL = 14, VT_I1 = 16, VT_UI1 = 17, VT_UI2 = 18, VT_UI4 = 19, VT_I8 = 20, VT_UI8 = 21, VT_INT = 22, VT_UINT = 23, VT_VOID = 24, VT_HRESULT = 25, VT_PTR = 26, VT_SAFEARRAY = 27, VT_CARRAY = 28, VT_USERDEFINED = 29, VT_LPSTR = 30, VT_LPWSTR = 31, VT_RECORD = 36, VT_INT_PTR = 37, VT_UINT_PTR = 38, VT_FILETIME = 64, VT_BLOB = 65, VT_STREAM = 66, VT_STORAGE = 67, VT_STREAMED_OBJECT = 68, VT_STORED_OBJECT = 69, VT_BLOB_OBJECT = 70, VT_CF = 71, VT_CLSID = 72, VT_VERSIONED_STREAM = 73, VT_BSTR_BLOB = 0xfff, VT_VECTOR = 0x1000, VT_ARRAY = 0x2000, VT_BYREF = 0x4000, VT_RESERVED = 0x8000, VT_ILLEGAL = 0xffff, VT_ILLEGALMASKED = 0xfff, VT_TYPEMASK = 0xfff };

pub const VT_EMPTY: WORD = 0;
pub const VT_NULL: WORD = 1;
pub const VT_I4: WORD = 3;
pub const VT_BSTR: WORD = 8;
pub const VT_BOOL: WORD = 11;
pub const VT_I2: WORD = 2;
pub const VT_R8: WORD = 5;
pub const VT_UNKNOWN: WORD = 13;
pub const VT_ARRAY: WORD = 0x2000;

pub const VARIANT_TRUE: i16 = -1;
pub const VARIANT_FALSE: i16 = 0;

pub const VARTYPE = WORD;
pub const VARIANT_BOOL = i16;
pub const SCODE = i32;
pub const LONGLONG = i64;
pub const SHORT = i16;
pub const ULONGLONG = u64;
pub const USHORT = u16;
pub const CHAR = i8;
pub const PVOID = *anyopaque;
pub const CY = extern union { // 8 bytes
    DUMMYSTRUCTNAME: extern struct { // 8 bytes
        Lo: ULONG,
        Hi: LONG,
    },
    int64: LONGLONG,
};
pub const DATE = f64; // DATE is a double
pub const DECIMAL = extern struct { // 16 bytes
    wReserved: USHORT,
    DUMMYUNIONNAME: extern union { // 2 bytes
        DUMMYSTRUCTNAME: extern struct {
            scale: BYTE,
            sign: BYTE,
        },
        signscale: USHORT,
    },
    Hi32: ULONG,
    DUMMYUNIONNAME2: extern union { // 8 bytes
        DUMMYSTRUCTNAME2: extern struct { // 8 bytes
            Lo32: ULONG,
            Mid32: ULONG,
        },
        Lo64: ULONGLONG,
    },
};

pub const IDispatch = opaque {};
pub const IRecordInfo = opaque {};

pub const VARIANT = extern struct {
    __VARIANT_NAME_1: extern union {
        __VARIANT_NAME_2: extern struct {
            vt: VARTYPE,
            wReserved1: WORD,
            wReserved2: WORD,
            wReserved3: WORD,
            __VARIANT_NAME_3: extern union {
                llVal: LONGLONG,
                lVal: LONG,
                bVal: BYTE,
                iVal: SHORT,
                fltVal: f32,
                dblVal: f64,
                boolVal: VARIANT_BOOL,
                __OBSOLETE__VARIANT_BOOL: VARIANT_BOOL,
                scode: SCODE,
                cyVal: CY,
                date: DATE,
                bstrVal: BSTR,
                punkVal: ?*IUnknown,
                pdispVal: ?*IDispatch,
                parray: ?*SAFEARRAY,
                pbVal: ?*BYTE,
                piVal: ?*SHORT,
                plVal: ?*LONG,
                pllVal: ?*LONGLONG,
                pfltVal: ?*f32,
                pdblVal: ?*f64,
                pboolVal: ?*VARIANT_BOOL,
                __OBSOLETE__VARIANT_PBOOL: ?*VARIANT_BOOL,
                pscode: ?*SCODE,
                pcyVal: ?*CY,
                pdate: ?*DATE,
                pbstrVal: ?*BSTR,
                ppunkVal: ?**IUnknown,
                ppdispVal: ?**IDispatch,
                pparray: ?**SAFEARRAY,
                pvarVal: ?*VARIANT,
                byref: PVOID,
                cVal: CHAR,
                uiVal: USHORT,
                ulVal: ULONG,
                ullVal: ULONGLONG,
                intVal: INT,
                uintVal: UINT,
                pdecVal: ?*DECIMAL,
                pcVal: ?*CHAR,
                puiVal: ?*USHORT,
                pulVal: ?*ULONG,
                pullVal: ?*ULONGLONG,
                pintVal: ?*INT,
                puintVal: ?*UINT,
                __VARIANT_NAME_4: extern struct {
                    pvRecord: PVOID,
                    pRecInfo: ?*IRecordInfo,
                },
            },
        },
        decVal: DECIMAL,
    },
};

pub const SAFEARRAY = extern struct {
    cDims: USHORT,
    fFeatures: USHORT,
    cbElements: ULONG,
    cLocks: ULONG,
    pvData: ?*anyopaque,
    rgsabound: [1]SAFEARRAYBOUND,
};

pub const SAFEARRAYBOUND = extern struct {
    cElements: ULONG,
    lLbound: LONG,
};

pub const UiaRect = extern struct {
    left: f64,
    top: f64,
    width: f64,
    height: f64,
};

// ============================================================================
// Window Messages
// ============================================================================

pub const WM_DESTROY: UINT = 0x0002;
pub const WM_QUIT: UINT = 0x0012;
pub const WM_GETOBJECT: UINT = 0x003D;
pub const WM_SETFOCUS: UINT = 0x0007;
pub const WM_KILLFOCUS: UINT = 0x0008;
pub const WM_KEYDOWN: UINT = 0x0100;

pub const UiaRootObjectId: LPARAM = -25;

// ============================================================================
// Window Styles
// ============================================================================

pub const WS_OVERLAPPEDWINDOW: DWORD = 0x00CF0000;
pub const WS_POPUP: DWORD = 0x80000000;
pub const WS_DISABLED: DWORD = 0x08000000;
pub const WS_EX_TOOLWINDOW: DWORD = 0x00000080;
pub const WS_EX_NOACTIVATE: DWORD = 0x08000000;

pub const CW_USEDEFAULT: INT = @bitCast(@as(u32, 0x80000000));

// ============================================================================
// UIA Provider Options
// ============================================================================

pub const ProviderOptions = enum(i32) {
    ClientSideProvider = 0x1,
    ServerSideProvider = 0x2,
    NonClientAreaProvider = 0x4,
    OverrideProvider = 0x8,
    ProviderOwnsSetFocus = 0x10,
    UseComThreading = 0x20,
    RefuseNonClientSupport = 0x40,
    HasNativeIAccessible = 0x80,
    UseClientCoordinates = 0x100,
};

// ============================================================================
// UIA Navigation Direction
// ============================================================================

pub const NavigateDirection = enum(i32) {
    Parent = 0,
    NextSibling = 1,
    PreviousSibling = 2,
    FirstChild = 3,
    LastChild = 4,
};

// ============================================================================
// UIA Structure Change Type
// ============================================================================

pub const StructureChangeType = enum(i32) {
    ChildAdded = 0,
    ChildRemoved = 1,
    ChildrenInvalidated = 2,
    ChildrenBulkAdded = 3,
    ChildrenBulkRemoved = 4,
    ChildrenReordered = 5,
};

// ============================================================================
// Toggle State
// ============================================================================

pub const ToggleState = enum(i32) {
    Off = 0,
    On = 1,
    Indeterminate = 2,
};

// ============================================================================
// UIA Notification Kind & Processing
// ============================================================================

pub const NotificationKind = enum(i32) {
    ItemAdded = 0,
    ItemRemoved = 1,
    ActionCompleted = 2,
    ActionAborted = 3,
    Other = 4,
};

pub const NotificationProcessing = enum(i32) {
    ImportantAll = 0,
    ImportantMostRecent = 1,
    All = 2,
    MostRecent = 3,
    CurrentThenMostRecent = 4,
};

pub const IID_IUnknown = GUID{
    // 00000000-0000-0000-C000-000000000046
    .Data1 = 0x00000000,
    .Data2 = 0x0000,
    .Data3 = 0x0000,
    .Data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 },
};

pub const IUnknown = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (*IUnknown, *const GUID, *?*anyopaque) callconv(cc) HRESULT,
        AddRef: *const fn (*IUnknown) callconv(cc) ULONG,
        Release: *const fn (*IUnknown) callconv(cc) ULONG,
    };
};

pub const IID_IRawElementProviderSimple = GUID{
    // D6DD68D1-86FD-4332-8666-9ABEDEA2D24C}
    .Data1 = 0xd6dd68d1,
    .Data2 = 0x86fd,
    .Data3 = 0x4332,
    .Data4 = .{ 0x86, 0x66, 0x9a, 0xbe, 0xde, 0xa2, 0xd2, 0x4c },
};

/// Don't use this
pub const IID_IRawElementProviderSimple2 = GUID{
    // A0A839A9-8DA1-4A82-806A-8E0D44E79F56
    .Data1 = 0xa0a839a9,
    .Data2 = 0x8da1,
    .Data3 = 0x4a82,
    .Data4 = .{ 0x80, 0x6a, 0x8e, 0x0d, 0x44, 0xe7, 0x9f, 0x56 },
};

pub const IRawElementProviderSimple = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*IRawElementProviderSimple, *const GUID, *?*anyopaque) callconv(cc) HRESULT,
        AddRef: *const fn (*IRawElementProviderSimple) callconv(cc) ULONG,
        Release: *const fn (*IRawElementProviderSimple) callconv(cc) ULONG,

        // IRawElementProviderSimple methods
        get_ProviderOptions: *const fn (*IRawElementProviderSimple, *i32) callconv(cc) HRESULT,
        GetPatternProvider: *const fn (*IRawElementProviderSimple, i32, *?*IUnknown) callconv(cc) HRESULT,
        GetPropertyValue: *const fn (*IRawElementProviderSimple, i32, *VARIANT) callconv(cc) HRESULT,
        get_HostRawElementProvider: *const fn (*IRawElementProviderSimple, *?*IRawElementProviderSimple) callconv(cc) HRESULT,
    };
};

pub const IID_IRawElementProviderFragment = GUID{
    // F7063DA8-8359-439C-9297-BBC5299A7D87
    .Data1 = 0xf7063da8,
    .Data2 = 0x8359,
    .Data3 = 0x439c,
    .Data4 = .{ 0x92, 0x97, 0xbb, 0xc5, 0x29, 0x9a, 0x7d, 0x87 },
};

pub const IRawElementProviderFragment = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*IRawElementProviderFragment, *const GUID, *?*anyopaque) callconv(cc) HRESULT,
        AddRef: *const fn (*IRawElementProviderFragment) callconv(cc) ULONG,
        Release: *const fn (*IRawElementProviderFragment) callconv(cc) ULONG,

        // IRawElementProviderFragment methods
        Navigate: *const fn (*IRawElementProviderFragment, NavigateDirection, *?*IRawElementProviderFragment) callconv(cc) HRESULT,
        GetRuntimeId: *const fn (*IRawElementProviderFragment, *?*SAFEARRAY) callconv(cc) HRESULT,
        get_BoundingRectangle: *const fn (*IRawElementProviderFragment, *UiaRect) callconv(cc) HRESULT,
        GetEmbeddedFragmentRoots: *const fn (*IRawElementProviderFragment, *?*SAFEARRAY) callconv(cc) HRESULT,
        SetFocus: *const fn (*IRawElementProviderFragment) callconv(cc) HRESULT,
        get_FragmentRoot: *const fn (*IRawElementProviderFragment, *?*IRawElementProviderFragmentRoot) callconv(cc) HRESULT,
    };
};

pub const IID_IRawElementProviderFragmentRoot = GUID{
    // 620CE2A5-AB8F-40A9-86CB-DE3C75599B58
    .Data1 = 0x620ce2a5,
    .Data2 = 0xab8f,
    .Data3 = 0x40a9,
    .Data4 = .{ 0x86, 0xcb, 0xde, 0x3c, 0x75, 0x59, 0x9b, 0x58 },
};

pub const IRawElementProviderFragmentRoot = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*IRawElementProviderFragmentRoot, *const GUID, *?*anyopaque) callconv(cc) HRESULT,
        AddRef: *const fn (*IRawElementProviderFragmentRoot) callconv(cc) ULONG,
        Release: *const fn (*IRawElementProviderFragmentRoot) callconv(cc) ULONG,

        // IRawElementProviderFragmentRoot methods
        ElementProviderFromPoint: *const fn (*IRawElementProviderFragmentRoot, f64, f64, *?*IRawElementProviderFragment) callconv(cc) HRESULT,
        GetFocus: *const fn (*IRawElementProviderFragmentRoot, *?*IRawElementProviderFragment) callconv(cc) HRESULT,
    };
};

// ============================================================================
// IInvokeProvider Interface
// ============================================================================

pub const IID_IInvokeProvider = GUID{
    .Data1 = 0x54fcb24b,
    .Data2 = 0xe18e,
    .Data3 = 0x47a2,
    .Data4 = .{ 0xb4, 0xd3, 0xec, 0xcb, 0xe7, 0x75, 0x99, 0xa2 },
};

pub const IInvokeProvider = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*IInvokeProvider, *const GUID, *?*anyopaque) callconv(cc) HRESULT,
        AddRef: *const fn (*IInvokeProvider) callconv(cc) ULONG,
        Release: *const fn (*IInvokeProvider) callconv(cc) ULONG,

        // IInvokeProvider methods
        Invoke: *const fn (*IInvokeProvider) callconv(cc) HRESULT,
    };
};

// ============================================================================
// IToggleProvider Interface
// ============================================================================

pub const IID_IToggleProvider = GUID{
    .Data1 = 0x56d00bd0,
    .Data2 = 0xc4f4,
    .Data3 = 0x433c,
    .Data4 = .{ 0xa8, 0x36, 0x1a, 0x52, 0xa5, 0x7e, 0x08, 0x92 },
};

pub const IToggleProvider = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*IToggleProvider, *const GUID, *?*anyopaque) callconv(cc) HRESULT,
        AddRef: *const fn (*IToggleProvider) callconv(cc) ULONG,
        Release: *const fn (*IToggleProvider) callconv(cc) ULONG,

        // IToggleProvider methods
        Toggle: *const fn (*IToggleProvider) callconv(cc) HRESULT,
        get_ToggleState: *const fn (*IToggleProvider, *ToggleState) callconv(cc) HRESULT,
    };
};

// ============================================================================
// IValueProvider Interface
// ============================================================================

pub const IID_IValueProvider = GUID{
    .Data1 = 0xc7935180,
    .Data2 = 0x6fb3,
    .Data3 = 0x4201,
    .Data4 = .{ 0xb1, 0x74, 0x7d, 0xf7, 0x3a, 0xdb, 0xf6, 0x4a },
};

pub const IValueProvider = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*IValueProvider, *const GUID, *?*anyopaque) callconv(cc) HRESULT,
        AddRef: *const fn (*IValueProvider) callconv(cc) ULONG,
        Release: *const fn (*IValueProvider) callconv(cc) ULONG,

        // IValueProvider methods
        SetValue: *const fn (*IValueProvider, LPCWSTR) callconv(cc) HRESULT,
        get_Value: *const fn (*IValueProvider, *BSTR) callconv(cc) HRESULT,
        get_IsReadOnly: *const fn (*IValueProvider, *BOOL) callconv(cc) HRESULT,
    };
};

// ============================================================================
// IRangeValueProvider Interface
// ============================================================================

pub const IID_IRangeValueProvider = GUID{
    .Data1 = 0x36dc7aef,
    .Data2 = 0x33e6,
    .Data3 = 0x4691,
    .Data4 = .{ 0x9a, 0xb7, 0xc3, 0x95, 0x64, 0xe3, 0x0f, 0x2c },
};

pub const IRangeValueProvider = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        // IUnknown methods
        QueryInterface: *const fn (*IRangeValueProvider, *const GUID, *?*anyopaque) callconv(cc) HRESULT,
        AddRef: *const fn (*IRangeValueProvider) callconv(cc) ULONG,
        Release: *const fn (*IRangeValueProvider) callconv(cc) ULONG,

        // IRangeValueProvider methods
        SetValue: *const fn (*IRangeValueProvider, f64) callconv(cc) HRESULT,
        get_Value: *const fn (*IRangeValueProvider, *f64) callconv(cc) HRESULT,
        get_IsReadOnly: *const fn (*IRangeValueProvider, *BOOL) callconv(cc) HRESULT,
        get_Maximum: *const fn (*IRangeValueProvider, *f64) callconv(cc) HRESULT,
        get_Minimum: *const fn (*IRangeValueProvider, *f64) callconv(cc) HRESULT,
        get_LargeChange: *const fn (*IRangeValueProvider, *f64) callconv(cc) HRESULT,
        get_SmallChange: *const fn (*IRangeValueProvider, *f64) callconv(cc) HRESULT,
    };
};

// ============================================================================
// Window class structures
// ============================================================================

pub const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(cc) LRESULT;

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXW),
    style: UINT = 0,
    lpfnWndProc: WNDPROC,
    cbClsExtra: INT = 0,
    cbWndExtra: INT = 0,
    hInstance: ?HINSTANCE = null,
    hIcon: ?HICON = null,
    hCursor: ?HCURSOR = null,
    hbrBackground: ?HBRUSH = null,
    lpszMenuName: ?LPCWSTR = null,
    lpszClassName: LPCWSTR,
    hIconSm: ?HICON = null,
};

pub const MSG = extern struct {
    hwnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};

pub const POINT = extern struct {
    x: LONG,
    y: LONG,
};

pub const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};

// ============================================================================
// COM initialization flags
// ============================================================================

pub const COINIT = packed struct(u32) {
    _reserved1: bool = false,
    APARTMENTTHREADED: bool = false,
    DISABLE_OLE1DDE: bool = false,
    SPEED_OVER_MEMORY: bool = false,
    _reserved2: u28 = 0,
};

pub const COINIT_MULTITHREADED: COINIT = .{};
pub const COINIT_APARTMENTTHREADED: COINIT = .{ .APARTMENTTHREADED = true };
pub const COINIT_DISABLE_OLE1DDE: COINIT = .{ .DISABLE_OLE1DDE = true };
pub const COINIT_SPEED_OVER_MEMORY: COINIT = .{ .SPEED_OVER_MEMORY = true };

// ============================================================================
// Runtime ID constant
// ============================================================================

pub const UiaAppendRuntimeId: i32 = 3;

// ============================================================================
// External Windows API functions (linking to system libraries)
// ============================================================================

// Declare external functions only on Windows
pub const user32 = if (builtin.os.tag == .windows) struct {
    pub extern "user32" fn RegisterClassExW(*const WNDCLASSEXW) callconv(cc) ATOM;
    pub extern "user32" fn CreateWindowExW(
        DWORD, // dwExStyle
        LPCWSTR, // lpClassName
        LPCWSTR, // lpWindowName
        DWORD, // dwStyle
        INT, // X
        INT, // Y
        INT, // nWidth
        INT, // nHeight
        ?HWND, // hWndParent
        ?HMENU, // hMenu
        ?HINSTANCE, // hInstance
        ?LPVOID, // lpParam
    ) callconv(cc) ?HWND;
    pub extern "user32" fn DestroyWindow(HWND) callconv(cc) BOOL;
    pub extern "user32" fn DefWindowProcW(HWND, UINT, WPARAM, LPARAM) callconv(cc) LRESULT;
    pub extern "user32" fn GetModuleHandleW(?LPCWSTR) callconv(cc) ?HMODULE;
    pub extern "user32" fn PostQuitMessage(INT) callconv(cc) void;
    pub extern "user32" fn ShowWindow(HWND, INT) callconv(cc) BOOL;
    pub extern "user32" fn UpdateWindow(HWND) callconv(cc) BOOL;
    pub extern "user32" fn GetWindowRect(HWND, *RECT) callconv(cc) BOOL;
    pub extern "user32" fn SetWindowPos(HWND, ?HWND, INT, INT, INT, INT, UINT) callconv(cc) BOOL;
    pub extern "user32" fn LoadCursorW(?HINSTANCE, LPCWSTR) callconv(cc) ?HCURSOR;
    pub extern "user32" fn GetMessageW(*MSG, ?HWND, UINT, UINT) callconv(cc) BOOL;
    pub extern "user32" fn PeekMessageW(*MSG, ?HWND, UINT, UINT, UINT) callconv(cc) BOOL;
    pub extern "user32" fn TranslateMessage(*const MSG) callconv(cc) BOOL;
    pub extern "user32" fn DispatchMessageW(*const MSG) callconv(cc) LRESULT;
} else struct {};

pub const kernel32 = if (builtin.os.tag == .windows) struct {
    pub extern "kernel32" fn GetModuleHandleW(?LPCWSTR) callconv(cc) ?HMODULE;
    pub extern "kernel32" fn GetCurrentProcessId() callconv(cc) DWORD;
    pub extern "kernel32" fn GetLastError() callconv(cc) DWORD;
} else struct {};

pub const ole32 = if (builtin.os.tag == .windows) struct {
    pub extern "ole32" fn CoInitializeEx(?*anyopaque, COINIT) callconv(cc) HRESULT;
    pub extern "ole32" fn CoUninitialize() callconv(cc) void;
} else struct {};

pub const oleaut32 = if (builtin.os.tag == .windows) struct {
    pub extern "oleaut32" fn SysAllocString(LPCWSTR) callconv(cc) BSTR;
    pub extern "oleaut32" fn SysFreeString(BSTR) callconv(cc) void;
    pub extern "oleaut32" fn SysStringLen(BSTR) callconv(cc) UINT;
    pub extern "oleaut32" fn SafeArrayCreateVector(WORD, LONG, ULONG) callconv(cc) ?*SAFEARRAY;
    pub extern "oleaut32" fn SafeArrayDestroy(?*SAFEARRAY) callconv(cc) HRESULT;
    pub extern "oleaut32" fn SafeArrayAccessData(?*SAFEARRAY, *?*anyopaque) callconv(cc) HRESULT;
    pub extern "oleaut32" fn SafeArrayUnaccessData(?*SAFEARRAY) callconv(cc) HRESULT;
    pub extern "oleaut32" fn VariantInit(*VARIANT) callconv(cc) void;
    pub extern "oleaut32" fn VariantClear(*VARIANT) callconv(cc) HRESULT;
} else struct {};

pub const uiautomationcore = if (builtin.os.tag == .windows) struct {
    pub extern "uiautomationcore" fn UiaReturnRawElementProvider(HWND, WPARAM, LPARAM, ?*IRawElementProviderSimple) callconv(cc) LRESULT;
    pub extern "uiautomationcore" fn UiaHostProviderFromHwnd(HWND, *?*IRawElementProviderSimple) callconv(cc) HRESULT;
    pub extern "uiautomationcore" fn UiaRaiseAutomationEvent(?*IRawElementProviderSimple, i32) callconv(cc) HRESULT;
    pub extern "uiautomationcore" fn UiaRaiseAutomationPropertyChangedEvent(?*IRawElementProviderSimple, i32, VARIANT, VARIANT) callconv(cc) HRESULT;
    pub extern "uiautomationcore" fn UiaRaiseStructureChangedEvent(?*IRawElementProviderSimple, StructureChangeType, ?[*]i32, i32) callconv(cc) HRESULT;
    pub extern "uiautomationcore" fn UiaClientsAreListening() callconv(cc) BOOL;
    pub extern "uiautomationcore" fn UiaDisconnectProvider(?*IRawElementProviderSimple) callconv(cc) HRESULT;
    pub extern "uiautomationcore" fn UiaDisconnectAllProviders() callconv(cc) HRESULT;
    pub extern "uiautomationcore" fn UiaRaiseNotificationEvent(
        ?*IRawElementProviderSimple,
        NotificationKind,
        NotificationProcessing,
        BSTR, // displayString
        BSTR, // activityId
    ) callconv(cc) HRESULT;
} else struct {};

// ============================================================================
// Helper functions
// ============================================================================

/// Convert a UTF-8 string to a null-terminated wide string (UTF-16)
pub fn utf8ToWide(allocator: std.mem.Allocator, str: []const u8) ![:0]WCHAR {
    const utf16 = try std.unicode.utf8ToUtf16LeAlloc(allocator, str);
    // Add null terminator
    const result = try allocator.allocSentinel(WCHAR, utf16.len, 0);
    @memcpy(result, utf16);
    allocator.free(utf16);
    return result;
}

/// Create a BSTR from a UTF-8 string
pub fn createBstr(allocator: std.mem.Allocator, str: []const u8) BSTR {
    if (builtin.os.tag != .windows) return null;

    const wide = utf8ToWide(allocator, str) catch return null;
    defer allocator.free(wide);
    return oleaut32.SysAllocString(wide.ptr);
}

/// Free a BSTR
pub fn freeBstr(bstr: BSTR) void {
    if (builtin.os.tag != .windows) return;
    if (bstr != null) {
        oleaut32.SysFreeString(bstr);
    }
}

/// Create a SAFEARRAY of i32 values
pub fn createRuntimeIdArray(allocator: std.mem.Allocator, values: []const i32) !?*SAFEARRAY {
    _ = allocator;
    if (builtin.os.tag != .windows) return null;

    const psa = oleaut32.SafeArrayCreateVector(VT_I4, 0, @intCast(values.len)) orelse return null;
    errdefer _ = oleaut32.SafeArrayDestroy(psa);

    var data_ptr: ?*anyopaque = null;
    if (FAILED(oleaut32.SafeArrayAccessData(psa, &data_ptr))) {
        _ = oleaut32.SafeArrayDestroy(psa);
        return null;
    }

    if (data_ptr) |ptr| {
        const arr: [*]i32 = @ptrCast(@alignCast(ptr));
        for (values, 0..) |val, i| {
            arr[i] = val;
        }
    }

    _ = oleaut32.SafeArrayUnaccessData(psa);
    return psa;
}
