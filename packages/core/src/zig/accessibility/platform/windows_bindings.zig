//! Windows API bindings for UI Automation
//!
//! This module provides Zig bindings for Windows COM types and UI Automation APIs.
//! Only compiles on Windows platform.

const std = @import("std");
const builtin = @import("builtin");

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

pub const HWND = *opaque {};
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
};

pub const IID = GUID;
pub const REFIID = *const IID;

// Common GUIDs
pub const IID_IUnknown = GUID{
    .Data1 = 0x00000000,
    .Data2 = 0x0000,
    .Data3 = 0x0000,
    .Data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 },
};

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

pub const VARIANT = extern struct {
    vt: WORD,
    wReserved1: WORD = 0,
    wReserved2: WORD = 0,
    wReserved3: WORD = 0,
    data: extern union {
        llVal: i64,
        lVal: i32,
        iVal: i16,
        bVal: u8,
        fltVal: f32,
        dblVal: f64,
        boolVal: i16,
        scode: i32,
        bstrVal: BSTR,
        punkVal: ?*IUnknown,
        parray: ?*SAFEARRAY,
    },

    pub fn initEmpty() VARIANT {
        return .{ .vt = VT_EMPTY, .data = .{ .llVal = 0 } };
    }

    pub fn initBool(val: bool) VARIANT {
        return .{
            .vt = VT_BOOL,
            .data = .{ .boolVal = if (val) VARIANT_TRUE else VARIANT_FALSE },
        };
    }

    pub fn initI4(val: i32) VARIANT {
        return .{
            .vt = VT_I4,
            .data = .{ .lVal = val },
        };
    }

    pub fn initBstr(bstr: BSTR) VARIANT {
        return .{
            .vt = VT_BSTR,
            .data = .{ .bstrVal = bstr },
        };
    }

    pub fn initR8(val: f64) VARIANT {
        return .{
            .vt = VT_R8,
            .data = .{ .dblVal = val },
        };
    }
};

// ============================================================================
// SAFEARRAY
// ============================================================================

pub const SAFEARRAY = extern struct {
    cDims: WORD,
    fFeatures: WORD,
    cbElements: ULONG,
    cLocks: ULONG,
    pvData: ?*anyopaque,
    rgsabound: [1]SAFEARRAYBOUND,
};

pub const SAFEARRAYBOUND = extern struct {
    cElements: ULONG,
    lLbound: LONG,
};

// ============================================================================
// UIA Rectangle
// ============================================================================

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
// UIA Control Types
// ============================================================================

pub const UIA_ButtonControlTypeId: i32 = 50000;
pub const UIA_CalendarControlTypeId: i32 = 50001;
pub const UIA_CheckBoxControlTypeId: i32 = 50002;
pub const UIA_ComboBoxControlTypeId: i32 = 50003;
pub const UIA_EditControlTypeId: i32 = 50004;
pub const UIA_HyperlinkControlTypeId: i32 = 50005;
pub const UIA_ImageControlTypeId: i32 = 50006;
pub const UIA_ListItemControlTypeId: i32 = 50007;
pub const UIA_ListControlTypeId: i32 = 50008;
pub const UIA_MenuControlTypeId: i32 = 50009;
pub const UIA_MenuBarControlTypeId: i32 = 50010;
pub const UIA_MenuItemControlTypeId: i32 = 50011;
pub const UIA_ProgressBarControlTypeId: i32 = 50012;
pub const UIA_RadioButtonControlTypeId: i32 = 50013;
pub const UIA_ScrollBarControlTypeId: i32 = 50014;
pub const UIA_SliderControlTypeId: i32 = 50015;
pub const UIA_SpinnerControlTypeId: i32 = 50016;
pub const UIA_StatusBarControlTypeId: i32 = 50017;
pub const UIA_TabControlTypeId: i32 = 50018;
pub const UIA_TabItemControlTypeId: i32 = 50019;
pub const UIA_TextControlTypeId: i32 = 50020;
pub const UIA_ToolBarControlTypeId: i32 = 50021;
pub const UIA_ToolTipControlTypeId: i32 = 50022;
pub const UIA_TreeControlTypeId: i32 = 50023;
pub const UIA_TreeItemControlTypeId: i32 = 50024;
pub const UIA_CustomControlTypeId: i32 = 50025;
pub const UIA_GroupControlTypeId: i32 = 50026;
pub const UIA_ThumbControlTypeId: i32 = 50027;
pub const UIA_DataGridControlTypeId: i32 = 50028;
pub const UIA_DataItemControlTypeId: i32 = 50029;
pub const UIA_DocumentControlTypeId: i32 = 50030;
pub const UIA_SplitButtonControlTypeId: i32 = 50031;
pub const UIA_WindowControlTypeId: i32 = 50032;
pub const UIA_PaneControlTypeId: i32 = 50033;
pub const UIA_HeaderControlTypeId: i32 = 50034;
pub const UIA_HeaderItemControlTypeId: i32 = 50035;
pub const UIA_TableControlTypeId: i32 = 50036;
pub const UIA_TitleBarControlTypeId: i32 = 50037;
pub const UIA_SeparatorControlTypeId: i32 = 50038;

// ============================================================================
// UIA Property IDs
// ============================================================================

pub const UIA_RuntimeIdPropertyId: i32 = 30000;
pub const UIA_BoundingRectanglePropertyId: i32 = 30001;
pub const UIA_ProcessIdPropertyId: i32 = 30002;
pub const UIA_ControlTypePropertyId: i32 = 30003;
pub const UIA_LocalizedControlTypePropertyId: i32 = 30004;
pub const UIA_NamePropertyId: i32 = 30005;
pub const UIA_AcceleratorKeyPropertyId: i32 = 30006;
pub const UIA_AccessKeyPropertyId: i32 = 30007;
pub const UIA_HasKeyboardFocusPropertyId: i32 = 30008;
pub const UIA_IsKeyboardFocusablePropertyId: i32 = 30009;
pub const UIA_IsEnabledPropertyId: i32 = 30010;
pub const UIA_AutomationIdPropertyId: i32 = 30011;
pub const UIA_ClassNamePropertyId: i32 = 30012;
pub const UIA_HelpTextPropertyId: i32 = 30013;
pub const UIA_ClickablePointPropertyId: i32 = 30014;
pub const UIA_CulturePropertyId: i32 = 30015;
pub const UIA_IsControlElementPropertyId: i32 = 30016;
pub const UIA_IsContentElementPropertyId: i32 = 30017;
pub const UIA_LabeledByPropertyId: i32 = 30018;
pub const UIA_IsPasswordPropertyId: i32 = 30019;
pub const UIA_NativeWindowHandlePropertyId: i32 = 30020;
pub const UIA_ItemTypePropertyId: i32 = 30021;
pub const UIA_IsOffscreenPropertyId: i32 = 30022;
pub const UIA_OrientationPropertyId: i32 = 30023;
pub const UIA_FrameworkIdPropertyId: i32 = 30024;
pub const UIA_IsRequiredForFormPropertyId: i32 = 30025;
pub const UIA_ItemStatusPropertyId: i32 = 30026;
pub const UIA_ValueValuePropertyId: i32 = 30045;
pub const UIA_ValueIsReadOnlyPropertyId: i32 = 30046;
pub const UIA_RangeValueValuePropertyId: i32 = 30047;
pub const UIA_RangeValueIsReadOnlyPropertyId: i32 = 30048;
pub const UIA_RangeValueMinimumPropertyId: i32 = 30049;
pub const UIA_RangeValueMaximumPropertyId: i32 = 30050;
pub const UIA_ToggleToggleStatePropertyId: i32 = 30086;

// ============================================================================
// UIA Pattern IDs
// ============================================================================

pub const UIA_InvokePatternId: i32 = 10000;
pub const UIA_SelectionPatternId: i32 = 10001;
pub const UIA_ValuePatternId: i32 = 10002;
pub const UIA_RangeValuePatternId: i32 = 10003;
pub const UIA_ScrollPatternId: i32 = 10004;
pub const UIA_ExpandCollapsePatternId: i32 = 10005;
pub const UIA_GridPatternId: i32 = 10006;
pub const UIA_GridItemPatternId: i32 = 10007;
pub const UIA_MultipleViewPatternId: i32 = 10008;
pub const UIA_WindowPatternId: i32 = 10009;
pub const UIA_SelectionItemPatternId: i32 = 10010;
pub const UIA_DockPatternId: i32 = 10011;
pub const UIA_TablePatternId: i32 = 10012;
pub const UIA_TableItemPatternId: i32 = 10013;
pub const UIA_TextPatternId: i32 = 10014;
pub const UIA_TogglePatternId: i32 = 10015;
pub const UIA_TransformPatternId: i32 = 10016;
pub const UIA_ScrollItemPatternId: i32 = 10017;
pub const UIA_LegacyIAccessiblePatternId: i32 = 10018;

// ============================================================================
// UIA Event IDs
// ============================================================================

pub const UIA_AutomationFocusChangedEventId: i32 = 20005;
pub const UIA_StructureChangedEventId: i32 = 20002;
pub const UIA_AsyncContentLoadedEventId: i32 = 20006;
pub const UIA_ToolTipOpenedEventId: i32 = 20000;
pub const UIA_ToolTipClosedEventId: i32 = 20001;
pub const UIA_MenuOpenedEventId: i32 = 20003;
pub const UIA_MenuClosedEventId: i32 = 20007;
pub const UIA_Invoke_InvokedEventId: i32 = 20009;
pub const UIA_SelectionItem_ElementSelectedEventId: i32 = 20012;
pub const UIA_LiveRegionChangedEventId: i32 = 20024;
pub const UIA_NotificationEventId: i32 = 20035;

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

// ============================================================================
// IUnknown Interface
// ============================================================================

pub const IUnknown = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (*IUnknown, *const GUID, *?*anyopaque) callconv(cc) HRESULT,
        AddRef: *const fn (*IUnknown) callconv(cc) ULONG,
        Release: *const fn (*IUnknown) callconv(cc) ULONG,
    };

    pub fn QueryInterface(self: *IUnknown, riid: *const GUID, ppvObject: *?*anyopaque) HRESULT {
        return self.vtable.QueryInterface(self, riid, ppvObject);
    }

    pub fn AddRef(self: *IUnknown) ULONG {
        return self.vtable.AddRef(self);
    }

    pub fn Release(self: *IUnknown) ULONG {
        return self.vtable.Release(self);
    }
};

// ============================================================================
// IRawElementProviderSimple Interface
// ============================================================================

pub const IID_IRawElementProviderSimple = GUID{
    .Data1 = 0xd6dd68d1,
    .Data2 = 0x86fd,
    .Data3 = 0x4332,
    .Data4 = .{ 0x86, 0x66, 0x9a, 0xbe, 0xde, 0xa2, 0xd2, 0x4c },
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

// ============================================================================
// IRawElementProviderFragment Interface
// ============================================================================

pub const IID_IRawElementProviderFragment = GUID{
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

        // IRawElementProviderSimple methods
        get_ProviderOptions: *const fn (*IRawElementProviderFragment, *i32) callconv(cc) HRESULT,
        GetPatternProvider: *const fn (*IRawElementProviderFragment, i32, *?*IUnknown) callconv(cc) HRESULT,
        GetPropertyValue: *const fn (*IRawElementProviderFragment, i32, *VARIANT) callconv(cc) HRESULT,
        get_HostRawElementProvider: *const fn (*IRawElementProviderFragment, *?*IRawElementProviderSimple) callconv(cc) HRESULT,

        // IRawElementProviderFragment methods
        Navigate: *const fn (*IRawElementProviderFragment, NavigateDirection, *?*IRawElementProviderFragment) callconv(cc) HRESULT,
        GetRuntimeId: *const fn (*IRawElementProviderFragment, *?*SAFEARRAY) callconv(cc) HRESULT,
        get_BoundingRectangle: *const fn (*IRawElementProviderFragment, *UiaRect) callconv(cc) HRESULT,
        GetEmbeddedFragmentRoots: *const fn (*IRawElementProviderFragment, *?*SAFEARRAY) callconv(cc) HRESULT,
        SetFocus: *const fn (*IRawElementProviderFragment) callconv(cc) HRESULT,
        get_FragmentRoot: *const fn (*IRawElementProviderFragment, *?*IRawElementProviderFragmentRoot) callconv(cc) HRESULT,
    };
};

// ============================================================================
// IRawElementProviderFragmentRoot Interface
// ============================================================================

pub const IID_IRawElementProviderFragmentRoot = GUID{
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

        // IRawElementProviderSimple methods
        get_ProviderOptions: *const fn (*IRawElementProviderFragmentRoot, *i32) callconv(cc) HRESULT,
        GetPatternProvider: *const fn (*IRawElementProviderFragmentRoot, i32, *?*IUnknown) callconv(cc) HRESULT,
        GetPropertyValue: *const fn (*IRawElementProviderFragmentRoot, i32, *VARIANT) callconv(cc) HRESULT,
        get_HostRawElementProvider: *const fn (*IRawElementProviderFragmentRoot, *?*IRawElementProviderSimple) callconv(cc) HRESULT,

        // IRawElementProviderFragment methods
        Navigate: *const fn (*IRawElementProviderFragmentRoot, NavigateDirection, *?*IRawElementProviderFragment) callconv(cc) HRESULT,
        GetRuntimeId: *const fn (*IRawElementProviderFragmentRoot, *?*SAFEARRAY) callconv(cc) HRESULT,
        get_BoundingRectangle: *const fn (*IRawElementProviderFragmentRoot, *UiaRect) callconv(cc) HRESULT,
        GetEmbeddedFragmentRoots: *const fn (*IRawElementProviderFragmentRoot, *?*SAFEARRAY) callconv(cc) HRESULT,
        SetFocus: *const fn (*IRawElementProviderFragmentRoot) callconv(cc) HRESULT,
        get_FragmentRoot: *const fn (*IRawElementProviderFragmentRoot, *?*IRawElementProviderFragmentRoot) callconv(cc) HRESULT,

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
pub fn createBstr(allocator: std.mem.Allocator, str: []const u8) !BSTR {
    if (builtin.os.tag != .windows) return null;

    const wide = try utf8ToWide(allocator, str);
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
