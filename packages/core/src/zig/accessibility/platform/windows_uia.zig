//! Windows UI Automation (UIA) accessibility implementation
//!
//! This module implements the platform bridge for Windows using the UI Automation API.
//! It creates a hidden window to host UIA providers and exposes the accessibility tree
//! to screen readers like NVDA, JAWS, and Narrator.
//!
//! Architecture:
//! - Creates a hidden HWND to host UIA providers
//! - Each AccessibilityNode gets a corresponding UIA provider object
//! - Implements IRawElementProviderSimple, IRawElementProviderFragment interfaces
//! - Raises UIA events for focus, property, and structure changes
//!
//! COM Object Model:
//! - UIAProvider implements IRawElementProviderFragment (and Simple via inheritance)
//! - UIARootProvider implements IRawElementProviderFragmentRoot
//! - Both implement control patterns based on node role (IInvokeProvider, etc.)

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform.zig");
const types = @import("../types.zig");
const node_mod = @import("../node.zig");
const logger = @import("../../logger.zig");
const win = @import("windows_bindings.zig");
const zigwin32 = @import("zigwin32");

const AccessibilityNode = node_mod.AccessibilityNode;
const PlatformBridge = platform.PlatformBridge;
const Allocator = std.mem.Allocator;

fn logToFile(comptime text: []const u8, args: anytype) void {
    const file_path = "zig_debug.log";
    const file = std.fs.cwd().createFile(file_path, .{ .truncate = false }) catch return;
    defer file.close();
    file.seekFromEnd(0) catch {};

    var buff: [4096]u8 = undefined;
    const str = std.fmt.bufPrint(&buff, text, args) catch "[Log failed]";

    file.writeAll(str) catch {};
    file.writeAll("\n") catch {};
}

var g_windows_uia: ?*WindowsUIA = null;

/// Root provider for the accessibility tree
/// Implements IRawElementProviderSimple, IRawElementProviderFragment, IRawElementProviderFragmentRoot
pub const UIARootProvider = struct {
    // These interfaces do not inherit from each other so we need separate vtable pointers
    iRawElementProviderSimple: win.IRawElementProviderSimple,
    iRawElementProviderFragment: win.IRawElementProviderFragment,
    iRawElementProviderFragmentRoot: win.IRawElementProviderFragmentRoot,

    ref_count: std.atomic.Value(u32),

    // Back-reference to UIA manager
    uia: *WindowsUIA,

    // Root node (if any)
    node: ?*AccessibilityNode,

    const Self = @This();

    pub fn create(allocator: Allocator, uia: *WindowsUIA) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .iRawElementProviderSimple = .{
                .vtable = &simple_vtable,
            },
            .iRawElementProviderFragment = .{
                .vtable = &fragment_vtable,
            },
            .iRawElementProviderFragmentRoot = .{
                .vtable = &root_vtable,
            },
            .ref_count = std.atomic.Value(u32).init(1),
            .uia = uia,
            .node = null,
        };
        return self;
    }

    pub fn asSimple(self: *Self) *win.IRawElementProviderSimple {
        return &self.iRawElementProviderSimple;
    }

    pub fn asFragment(self: *Self) *win.IRawElementProviderFragment {
        return &self.iRawElementProviderFragment;
    }

    pub fn asFragmentRoot(self: *Self) *win.IRawElementProviderFragmentRoot {
        return &self.iRawElementProviderFragmentRoot;
    }

    pub fn getSelfFromSimple(ptr: *win.IRawElementProviderSimple) *Self {
        return @fieldParentPtr("iRawElementProviderSimple", ptr);
    }

    pub fn getSelfFromFragment(ptr: *win.IRawElementProviderFragment) *Self {
        return @fieldParentPtr("iRawElementProviderFragment", ptr);
    }

    pub fn getSelfFromFragmentRoot(ptr: *win.IRawElementProviderFragmentRoot) *Self {
        return @fieldParentPtr("iRawElementProviderFragmentRoot", ptr);
    }

    pub fn addRef(self: *Self) u32 {
        return self.ref_count.fetchAdd(1, .monotonic) + 1;
    }

    pub fn release(self: *Self) u32 {
        const old = self.ref_count.fetchSub(1, .acq_rel);
        if (old == 1) {
            self.uia.allocator.destroy(self);
            return 0;
        }
        return old - 1;
    }

    fn queryInterface(self: *Self, riid: *const win.GUID, ppv: *?*anyopaque) callconv(win.cc) win.HRESULT {
        if (@intFromPtr(ppv) == 0) {
            return win.E_POINTER;
        }

        ppv.* = null;
        if (riid.eql(&win.IID_IUnknown) or riid.eql(&win.IID_IRawElementProviderSimple)) {
            ppv.* = self.asSimple();
        } else if (riid.eql(&win.IID_IRawElementProviderFragment)) {
            ppv.* = self.asFragment();
        } else if (riid.eql(&win.IID_IRawElementProviderFragmentRoot)) {
            ppv.* = self.asFragmentRoot();
        } else {
            return win.E_NOINTERFACE;
        }

        _ = self.addRef();
        return win.S_OK;
    }

    fn addRefSimple(ptr: *win.IRawElementProviderSimple) callconv(win.cc) win.ULONG {
        return getSelfFromSimple(ptr).addRef();
    }

    fn releaseSimple(ptr: *win.IRawElementProviderSimple) callconv(win.cc) win.ULONG {
        return getSelfFromSimple(ptr).release();
    }

    fn queryInterfaceSimple(ptr: *win.IRawElementProviderSimple, riid: *const win.GUID, ppv: *?*anyopaque) callconv(win.cc) win.HRESULT {
        return getSelfFromSimple(ptr).queryInterface(riid, ppv);
    }

    fn addRefFragment(ptr: *win.IRawElementProviderFragment) callconv(win.cc) win.ULONG {
        return getSelfFromFragment(ptr).addRef();
    }

    fn releaseFragment(ptr: *win.IRawElementProviderFragment) callconv(win.cc) win.ULONG {
        return getSelfFromFragment(ptr).release();
    }

    fn queryInterfaceFragment(ptr: *win.IRawElementProviderFragment, riid: *const win.GUID, ppv: *?*anyopaque) callconv(win.cc) win.HRESULT {
        return getSelfFromFragment(ptr).queryInterface(riid, ppv);
    }

    fn addRefRoot(ptr: *win.IRawElementProviderFragmentRoot) callconv(win.cc) win.ULONG {
        return getSelfFromFragmentRoot(ptr).addRef();
    }

    fn releaseRoot(ptr: *win.IRawElementProviderFragmentRoot) callconv(win.cc) win.ULONG {
        return getSelfFromFragmentRoot(ptr).release();
    }

    fn queryInterfaceRoot(ptr: *win.IRawElementProviderFragmentRoot, riid: *const win.GUID, ppv: *?*anyopaque) callconv(win.cc) win.HRESULT {
        return getSelfFromFragmentRoot(ptr).queryInterface(riid, ppv);
    }

    fn getProviderOptions(ptr: *win.IRawElementProviderSimple, options: *i32) callconv(win.cc) win.HRESULT {
        if (@intFromPtr(ptr) == 0) {
            logToFile("UIA Root: getProviderOptions called with null self pointer", .{});
            return win.E_POINTER;
        }
        if (@intFromPtr(options) == 0) {
            logToFile("UIA Root: getProviderOptions called with null options pointer", .{});
            return win.E_POINTER;
        }

        options.* = @intFromEnum(win.ProviderOptions.ServerSideProvider) | @intFromEnum(win.ProviderOptions.UseComThreading);
        return win.S_OK;
    }

    fn getPatternProvider(_: *win.IRawElementProviderSimple, _: i32, ret: *?*win.IUnknown) callconv(win.cc) win.HRESULT {
        logToFile("UIA Root: getPatternProvider called", .{});

        if (@intFromPtr(ret) == 0) {
            logToFile("UIA Root: getPatternProvider called with null ret pointer", .{});
            return win.E_POINTER;
        }
        // Root doesn't implement any patterns
        ret.* = null;
        logToFile("UIA Root: getPatternProvider returning S_OK", .{});
        return win.S_OK;
    }

    fn getPropertyValue(ptr: *win.IRawElementProviderSimple, property_id: i32, ret: *win.VARIANT) callconv(win.cc) win.HRESULT {
        if (@intFromPtr(ret) == 0) {
            logToFile("UIA Root: getPropertyValue called with null ret pointer", .{});
            return win.E_POINTER;
        }
        const self = getSelfFromSimple(ptr);
        win.oleaut32.VariantInit(ret);

        const property_id_enum: win.UIA_IDs.PropertyIds = @enumFromInt(property_id);
        switch (property_id_enum) {
            .UIA_NamePropertyId => {
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.vt = win.VT_BSTR;
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.__VARIANT_NAME_3.bstrVal = win.createBstr(self.uia.allocator, "OpenTUI Accessibility Host");
                logToFile("UIA Root: getPropertyValue returning Name 'OpenTUI Accessibility Host'", .{});
            },
            .UIA_ControlTypePropertyId => {
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.vt = win.VT_I4;
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.__VARIANT_NAME_3.lVal = @intFromEnum(win.UIA_IDs.ControlTypeIds.UIA_PaneControlTypeId);
                logToFile("UIA Root: getPropertyValue returning ControlType Pane", .{});
            },
            .UIA_IsKeyboardFocusablePropertyId => {
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.vt = win.VT_BOOL;
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.__VARIANT_NAME_3.boolVal = win.VARIANT_TRUE;
                logToFile("UIA Root: getPropertyValue returning IsKeyboardFocusable TRUE", .{});
            },
            .UIA_HasKeyboardFocusPropertyId => {
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.vt = win.VT_BOOL;
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.__VARIANT_NAME_3.boolVal = win.VARIANT_TRUE;
                logToFile("UIA Root: getPropertyValue returning HasKeyboardFocus TRUE", .{});
            },
            .UIA_IsContentElementPropertyId, .UIA_IsControlElementPropertyId => {
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.vt = win.VT_BOOL;
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.__VARIANT_NAME_3.boolVal = win.VARIANT_TRUE;
                logToFile("UIA Root: getPropertyValue returning IsContentElement/IsControlElement TRUE", .{});
            },
            .UIA_AutomationIdPropertyId => {
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.vt = win.VT_BSTR;
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.__VARIANT_NAME_3.bstrVal = win.createBstr(self.uia.allocator, "OpenTUI_Root") orelse null;
                logToFile("UIA Root: getPropertyValue returning AutomationId 'OpenTUI_Root'", .{});
            },
            .UIA_LocalizedControlTypePropertyId => {
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.vt = win.VT_BSTR;
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.__VARIANT_NAME_3.bstrVal = win.createBstr(self.uia.allocator, "pane") orelse null;
                logToFile("UIA Root: getPropertyValue returning LocalizedControlType 'pane'", .{});
            },
            else => {
                ret.__VARIANT_NAME_1.__VARIANT_NAME_2.vt = win.VT_EMPTY;
                logToFile("UIA Root: getPropertyValue called for unsupported property ID {d}, returning VT_EMPTY", .{property_id});
            },
        }

        return win.S_OK;
    }

    fn getHostRawElementProvider(ptr: *win.IRawElementProviderSimple, ret: *?*win.IRawElementProviderSimple) callconv(win.cc) win.HRESULT {
        if (@intFromPtr(ret) == 0) {
            return win.E_POINTER;
        }

        const self = getSelfFromSimple(ptr);
        return win.uiautomationcore.UiaHostProviderFromHwnd(self.uia.hwnd.?, ret);
    }

    fn navigate(ptr: *win.IRawElementProviderFragment, direction: win.NavigateDirection, ret: *?*win.IRawElementProviderFragment) callconv(win.cc) win.HRESULT {
        if (@intFromPtr(ret) == 0) {
            logToFile("UIA Root: navigate called with null ret pointer", .{});
            return win.E_POINTER;
        }

        _ = getSelfFromFragment(ptr);
        ret.* = null;

        // Root has no parent or siblings
        switch (direction) {
            // .FirstChild => {
            //     if (self.node) |root_node| {
            //         if (root_node.children_ids.items.len > 0) {
            //             const first_id = root_node.children_ids.items[0];
            //             if (self.uia.providers.get(first_id)) |child| {
            //                 _ = child.addRef();
            //                 ret.* = child.asFragment();
            //             }
            //         }
            //     }
            // },
            // .LastChild => {
            //     if (self.node) |root_node| {
            //         const len = root_node.children_ids.items.len;
            //         if (len > 0) {
            //             const last_id = root_node.children_ids.items[len - 1];
            //             if (self.uia.providers.get(last_id)) |child| {
            //                 _ = child.addRef();
            //                 ret.* = child.asFragment();
            //             }
            //         }
            //     }
            // },
            .Parent, .NextSibling, .PreviousSibling, .FirstChild, .LastChild => {
                // Root has no parent or siblings
            },
        }

        return win.S_OK;
    }

    fn getRuntimeId(_: *win.IRawElementProviderFragment, ret: *?*win.SAFEARRAY) callconv(win.cc) win.HRESULT {
        if (@intFromPtr(ret) == 0) {
            return win.E_POINTER;
        }

        // Root element returns NULL, it uses the host window's runtime ID
        ret.* = null;
        return win.S_OK;
    }

    fn getBoundingRectangle(ptr: *win.IRawElementProviderFragment, ret: *win.UiaRect) callconv(win.cc) win.HRESULT {
        if (@intFromPtr(ret) == 0) {
            return win.E_POINTER;
        }

        _ = getSelfFromFragment(ptr);
        // if (self.uia.hwnd) |hwnd| {
        //     var rect: win.RECT = undefined;
        //     _ = win.user32.GetWindowRect(hwnd, &rect);
        //     ret.* = .{
        //         .left = @floatFromInt(rect.left),
        //         .top = @floatFromInt(rect.top),
        //         .width = @floatFromInt(rect.right - rect.left),
        //         .height = @floatFromInt(rect.bottom - rect.top),
        //     };
        // } else {
        //     ret.* = .{ .left = 0, .top = 0, .width = 0, .height = 0 };
        // }

        ret.* = .{ .left = 0, .top = 0, .width = 0, .height = 0 };
        logToFile("UIA Root: getBoundingRectangle returning rect {d}, {d}, {d}, {d}", .{ ret.*.left, ret.*.top, ret.*.width, ret.*.height });
        return win.S_OK;
    }

    fn getEmbeddedFragmentRoots(ptr: *win.IRawElementProviderFragment, ret: *?*win.SAFEARRAY) callconv(win.cc) win.HRESULT {
        if (@intFromPtr(ret) == 0) {
            logToFile("UIA Root: getEmbeddedFragmentRoots called with null ret pointer", .{});
            return win.E_POINTER;
        }

        _ = getSelfFromFragment(ptr);

        // TODO: return children that are fragment roots
        ret.* = null;
        return win.S_OK;
    }

    fn setFocus(ptr: *win.IRawElementProviderFragment) callconv(win.cc) win.HRESULT {
        _ = getSelfFromFragment(ptr);

        // TODO
        return win.S_OK;
    }

    fn getFragmentRoot(ptr: *win.IRawElementProviderFragment, ret: *?*win.IRawElementProviderFragmentRoot) callconv(win.cc) win.HRESULT {
        if (@intFromPtr(ret) == 0) {
            return win.E_POINTER;
        }

        const self = getSelfFromFragment(ptr);
        _ = self.addRef();
        ret.* = self.asFragmentRoot();
        return win.S_OK;
    }

    fn elementProviderFromPoint(ptr: *win.IRawElementProviderFragmentRoot, x: f64, y: f64, ret: *?*win.IRawElementProviderFragment) callconv(win.cc) win.HRESULT {
        if (@intFromPtr(ret) == 0) {
            return win.E_POINTER;
        }

        _ = x;
        _ = y;

        const self = getSelfFromFragmentRoot(ptr);
        ret.* = null;

        _ = self.addRef();
        ret.* = self.asFragment();
        return win.S_OK;
    }

    fn getFocus(ptr: *win.IRawElementProviderFragmentRoot, ret: *?*win.IRawElementProviderFragment) callconv(win.cc) win.HRESULT {
        if (@intFromPtr(ret) == 0) {
            return win.E_POINTER;
        }

        const self = getSelfFromFragmentRoot(ptr);
        _ = self.addRef();
        ret.* = self.asFragment();
        return win.S_OK;
    }

    const simple_vtable = win.IRawElementProviderSimple.VTable{
        // IUnknown
        .AddRef = addRefSimple,
        .QueryInterface = queryInterfaceSimple,
        .Release = releaseSimple,
        // IRawElementProviderSimple
        .get_ProviderOptions = getProviderOptions,
        .GetPatternProvider = getPatternProvider,
        .GetPropertyValue = getPropertyValue,
        .get_HostRawElementProvider = getHostRawElementProvider,
    };

    const fragment_vtable = win.IRawElementProviderFragment.VTable{
        // IUnknown
        .AddRef = addRefFragment,
        .QueryInterface = queryInterfaceFragment,
        .Release = releaseFragment,
        // IRawElementProviderFragment
        .Navigate = navigate,
        .GetRuntimeId = getRuntimeId,
        .get_BoundingRectangle = getBoundingRectangle,
        .GetEmbeddedFragmentRoots = getEmbeddedFragmentRoots,
        .SetFocus = setFocus,
        .get_FragmentRoot = getFragmentRoot,
    };

    const root_vtable = win.IRawElementProviderFragmentRoot.VTable{
        // IUnknown
        .QueryInterface = queryInterfaceRoot,
        .AddRef = addRefRoot,
        .Release = releaseRoot,
        // IRawElementProviderFragmentRoot
        .ElementProviderFromPoint = elementProviderFromPoint,
        .GetFocus = getFocus,
    };
};

// ============================================================================
// WindowsUIA - Main UIA bridge
// ============================================================================

pub const WindowsUIA = struct {
    allocator: Allocator,
    action_callback: ?types.ActionCallback,

    hwnd: ?zigwin32.foundation.HWND,
    com_initialized: bool,
    initialized: bool,

    // Provider management
    root_provider: ?*UIARootProvider,
    // providers: std.StringHashMap(*UIAProvider),
    // focused_provider: ?*UIAProvider,

    // Node tracking (to resolve parent/child relationships)
    // root_node: ?*AccessibilityNode,
    bridge_nodes: std.StringHashMap(*AccessibilityNode),

    // Pattern vtable pointers (shared across all providers)
    // invoke_vtable_ptr: *const win.IInvokeProvider.VTable,
    // toggle_vtable_ptr: *const win.IToggleProvider.VTable,
    // value_vtable_ptr: *const win.IValueProvider.VTable,

    const Self = @This();
    const CLASS_NAME = std.unicode.utf8ToUtf16LeStringLiteral("OpenTUI_UIA_Host");

    pub fn create(allocator: Allocator) !PlatformBridge {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .action_callback = null,
            .hwnd = null,
            .com_initialized = false,
            .initialized = false,
            .root_provider = null,
            // .providers = std.StringHashMap(*UIAProvider).init(allocator),
            // .focused_provider = null,
            // .root_node = null,
            .bridge_nodes = std.StringHashMap(*AccessibilityNode).init(allocator),
            // .invoke_vtable_ptr = &invoke_vtable,
            // .toggle_vtable_ptr = &toggle_vtable,
            // .value_vtable_ptr = &value_vtable,
        };

        // Store global reference for window procedure
        g_windows_uia = self;

        // Initialize Windows UIA
        self.initializeUIA() catch |err| {
            logger.warn("Failed to initialize Windows UIA: {any}", .{err});
            // Continue with uninitialized state - methods will be no-ops
        };

        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    fn initializeUIA(self: *Self) !void {
        if (builtin.os.tag != .windows) {
            return;
        }

        const hInstance = zigwin32.system.library_loader.GetModuleHandleW(null);

        // The docs aren't happy about using COINIT_MULTITHREADED in a GUI program but we need raw performance
        const hr = zigwin32.system.com.CoInitializeEx(null, zigwin32.system.com.COINIT_MULTITHREADED);
        if (zigwin32.zig.FAILED(hr)) {
            logger.err("Failed to initialize COM: 0x{X}", .{@as(u32, @bitCast(hr))});
            return error.InitializationFailed;
        }
        logger.debug("COM initialized for Windows UIA: 0x{X}", .{@as(u32, @bitCast(hr))});
        self.com_initialized = true;

        // Register window class
        const wc = zigwin32.ui.windows_and_messaging.WNDCLASSEXW{
            .cbSize = @sizeOf(zigwin32.ui.windows_and_messaging.WNDCLASSEXW),
            .style = zigwin32.ui.windows_and_messaging.WNDCLASS_STYLES{},
            .lpfnWndProc = windowProc,
            .cbClsExtra = 0,
            .cbWndExtra = 0,
            .hInstance = hInstance,
            .hIcon = null,
            .hCursor = zigwin32.ui.windows_and_messaging.LoadCursorW(null, zigwin32.ui.windows_and_messaging.IDC_ARROW),
            .hbrBackground = @ptrFromInt(@intFromEnum(zigwin32.ui.windows_and_messaging.COLOR_WINDOW) + 1),
            .lpszMenuName = null,
            .lpszClassName = CLASS_NAME,
            .hIconSm = null,
        };

        if (zigwin32.ui.windows_and_messaging.RegisterClassExW(&wc) == 0) {
            const err = zigwin32.foundation.GetLastError();
            // Class already exists is OK
            if (err != .ERROR_CLASS_ALREADY_EXISTS) {
                logger.err("Failed to register UIA host window class: {any}", .{err});
                _ = zigwin32.system.com.CoUninitialize();
                return error.InitializationFailed;
            }
        }
        logger.debug("Registered UIA host window class", .{});

        // Create window for hosting UIA providers
        // Using WS_EX_TOOLWINDOW to hide from taskbar, WS_EX_NOACTIVATE to not steal focus
        self.hwnd = zigwin32.ui.windows_and_messaging.CreateWindowExW(
            // win.WS_EX_TOOLWINDOW | win.WS_EX_NOACTIVATE,
            zigwin32.ui.windows_and_messaging.WINDOW_EX_STYLE{},
            CLASS_NAME,
            std.unicode.utf8ToUtf16LeStringLiteral("OpenTUI Accessibility"),
            // win.WS_POPUP | win.WS_DISABLED, // Popup window, disabled - minimal overhead
            // zigwin32.ui.windows_and_messaging.WS_OVERLAPPEDWINDOW,
            @bitCast(win.WS_OVERLAPPEDWINDOW),
            @bitCast(@as(u32, 0x80000000)),
            @bitCast(@as(u32, 0x80000000)),
            400,
            300,
            null, // No parent
            null, // No menu
            hInstance,
            null, // No param
        );

        if (self.hwnd == null) {
            logger.err("Failed to create UIA host window", .{});
            _ = zigwin32.system.com.CoUninitialize();
            return error.InitializationFailed;
        }

        self.root_provider = UIARootProvider.create(self.allocator, self) catch {
            logger.err("Failed to create UIA root provider", .{});
            _ = zigwin32.ui.windows_and_messaging.DestroyWindow(self.hwnd.?);
            self.hwnd = null;
            _ = zigwin32.system.com.CoUninitialize();
            return error.InitializationFailed;
        };

        errdefer {
            _ = self.root_provider.?.release();
            self.root_provider = null;
        }

        _ = zigwin32.ui.windows_and_messaging.ShowWindow(self.hwnd.?, zigwin32.ui.windows_and_messaging.SW_NORMAL);
        _ = zigwin32.graphics.gdi.UpdateWindow(self.hwnd.?);

        logger.info("Windows UIA accessibility bridge initialized (hwnd={*})", .{self.hwnd});
        self.initialized = true;
    }

    fn windowProc(hwnd: zigwin32.foundation.HWND, msg: u32, wParam: zigwin32.foundation.WPARAM, lParam: zigwin32.foundation.LPARAM) callconv(.c) zigwin32.foundation.LRESULT {
        switch (msg) {
            zigwin32.ui.windows_and_messaging.WM_GETOBJECT => {
                // Handle UIA requests
                if (lParam == win.UiaRootObjectId) {
                    if (g_windows_uia) |uia| {
                        if (uia.root_provider) |root| {
                            // _ = root.addRef();
                            return win.uiautomationcore.UiaReturnRawElementProvider(
                                hwnd,
                                wParam,
                                lParam,
                                root.asSimple(),
                            );
                        }
                    }
                }
            },
            zigwin32.ui.windows_and_messaging.WM_DESTROY => {
                _ = zigwin32.ui.windows_and_messaging.PostQuitMessage(0);
                return 0;
            },
            zigwin32.ui.windows_and_messaging.WM_CLOSE => {
                _ = zigwin32.ui.windows_and_messaging.DestroyWindow(hwnd);
                return 0;
            },
            else => {},
        }
        return zigwin32.ui.windows_and_messaging.DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (builtin.os.tag != .windows) {
            self.allocator.destroy(self);
            return;
        }

        // Disconnect all providers from UIA
        // if (self.hwnd) |hwnd| {
        //     _ = win.uiautomationcore.UiaReturnRawElementProvider(hwnd, 0, 0, null);
        // }

        // Release all providers
        // var iter = self.providers.valueIterator();
        // while (iter.next()) |provider_ptr| {
        //     _ = provider_ptr.*.release();
        // }
        // self.providers.deinit();
        self.bridge_nodes.deinit();

        if (self.root_provider) |root| {
            _ = root.release();
        }

        if (self.hwnd) |hwnd| {
            _ = zigwin32.ui.windows_and_messaging.DestroyWindow(hwnd);
        }

        if (self.com_initialized) {
            zigwin32.system.com.CoUninitialize();
        }

        g_windows_uia = null;
        self.allocator.destroy(self);
    }

    fn addNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        _ = node;

        // // Track the node for hierarchy resolution
        // self.bridge_nodes.put(node.id, node) catch return error.OutOfMemory;

        // // If this is a root node (no parent), set it as root
        // if (node.parent_id == null) {
        //     self.root_node = node;
        //     if (self.root_provider) |root| {
        //         root.node = node;
        //     }
        //     logger.debug("UIA: Set root node '{s}'", .{node.id});
        //     return;
        // }

        // // Create provider for this node
        // const provider = UIAProvider.create(self.allocator, node, self) catch return error.OutOfMemory;
        // self.providers.put(node.id, provider) catch {
        //     _ = provider.release();
        //     return error.OutOfMemory;
        // };

        // // Raise structure changed event
        // if (self.root_provider) |root| {
        //     _ = win.uiautomationcore.UiaRaiseStructureChangedEvent(
        //         root.asSimple(),
        //         .ChildAdded,
        //         null,
        //         0,
        //     );
        // }

        // logger.debug("UIA: Added node '{s}' with role {s}", .{ node.id, node.role.name() });
    }

    fn updateNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        _ = node;

        // // Update tracked node
        // self.bridge_nodes.put(node.id, node) catch return error.OutOfMemory;

        // logger.debug("UIA: Updated node '{s}'", .{node.id});
    }

    fn removeNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        _ = node;

        // // Remove from tracking
        // _ = self.bridge_nodes.remove(node.id);

        // // Clear focus if this was focused
        // if (self.focused_provider) |focused| {
        //     if (std.mem.eql(u8, focused.node.id, node.id)) {
        //         self.focused_provider = null;
        //     }
        // }

        // // Remove and release provider
        // if (self.providers.fetchRemove(node.id)) |kv| {
        //     const provider = kv.value;

        //     // Raise structure changed event before removal
        //     _ = win.uiautomationcore.UiaRaiseStructureChangedEvent(
        //         provider.asSimple(),
        //         .ChildRemoved,
        //         null,
        //         0,
        //     );

        //     // Disconnect from UIA
        //     _ = win.uiautomationcore.UiaDisconnectProvider(provider.asSimple());

        //     _ = provider.release();
        // }

        // // Clear root if this was root
        // if (self.root_node) |root| {
        //     if (std.mem.eql(u8, root.id, node.id)) {
        //         self.root_node = null;
        //         if (self.root_provider) |rp| {
        //             rp.node = null;
        //         }
        //     }
        // }

        // logger.debug("UIA: Removed node '{s}'", .{node.id});
    }

    fn notifyFocusChanged(ctx: *anyopaque, node: ?*AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        _ = node;

        // if (node) |n| {
        //     if (self.providers.get(n.id)) |provider| {
        //         self.focused_provider = provider;

        //         // Raise focus changed event
        //         _ = win.uiautomationcore.UiaRaiseAutomationEvent(
        //             provider.asSimple(),
        //             win.UIA_AutomationFocusChangedEventId,
        //         );

        //         logger.debug("UIA: Focus changed to node '{s}'", .{n.id});
        //     }
        // } else {
        //     self.focused_provider = null;
        //     logger.debug("UIA: Focus cleared", .{});
        // }
    }

    fn notifyPropertyChanged(ctx: *anyopaque, node: *AccessibilityNode, property: types.Property) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        _ = node;
        _ = property;

        // if (self.providers.get(node.id)) |provider| {
        //     // Map property to UIA property ID and raise event
        //     const uia_prop_id: i32 = switch (property) {
        //         .name => win.UIA_NamePropertyId,
        //         .value => win.UIA_ValueValuePropertyId,
        //         .state => win.UIA_ToggleToggleStatePropertyId,
        //         else => return, // Other properties not mapped
        //     };

        //     const old_val = win.VARIANT.initEmpty();
        //     var new_val = win.VARIANT.initEmpty();

        //     // For toggle state changes
        //     if (property == .state and (node.role == .checkbox or node.role == .radio)) {
        //         const state: win.ToggleState = if (node.state.checked) .On else .Off;
        //         new_val = win.VARIANT.initI4(@intFromEnum(state));
        //     }

        //     _ = win.uiautomationcore.UiaRaiseAutomationPropertyChangedEvent(
        //         provider.asSimple(),
        //         uia_prop_id,
        //         old_val,
        //         new_val,
        //     );

        //     logger.debug("UIA: Property '{s}' changed for node '{s}'", .{ @tagName(property), node.id });
        // }
    }

    fn announce(ctx: *anyopaque, message: []const u8, priority: types.LiveSetting) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        _ = message;
        _ = priority;

        // // Use UiaRaiseNotificationEvent for announcements
        // if (self.root_provider) |root| {
        //     const bstr_msg = win.createBstr(self.allocator, message) catch return error.OutOfMemory;
        //     defer win.freeBstr(bstr_msg);

        //     const processing: win.NotificationProcessing = switch (priority) {
        //         .off => .All,
        //         .polite => .All,
        //         .assertive => .ImportantAll,
        //     };

        //     _ = win.uiautomationcore.UiaRaiseNotificationEvent(
        //         root.asSimple(),
        //         .Other,
        //         processing,
        //         bstr_msg,
        //         null, // activityId
        //     );

        //     logger.debug("UIA: Announce ({s}): {s}", .{ @tagName(priority), message });
        // }
    }

    fn setActionCallback(ctx: *anyopaque, callback: ?types.ActionCallback) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.action_callback = callback;
    }

    // This function is called in each rendering iteration
    pub fn tick(ctx: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized or self.hwnd == null) return;

        var msg: zigwin32.ui.windows_and_messaging.MSG = undefined;
        // We use PeekMessage here instead of GetMessage to avoid blocking
        while (zigwin32.ui.windows_and_messaging.PeekMessageW(&msg, self.hwnd.?, 0, 0, zigwin32.ui.windows_and_messaging.PM_REMOVE) != 0) {
            if (msg.message == zigwin32.ui.windows_and_messaging.WM_QUIT) {
                logger.info("UIA host window received WM_QUIT", .{});
                break;
            }
            _ = zigwin32.ui.windows_and_messaging.TranslateMessage(&msg);
            _ = zigwin32.ui.windows_and_messaging.DispatchMessageW(&msg);
        }
    }

    const vtable = PlatformBridge.VTable{
        .deinit = deinit,
        .addNode = addNode,
        .updateNode = updateNode,
        .removeNode = removeNode,
        .notifyFocusChanged = notifyFocusChanged,
        .notifyPropertyChanged = notifyPropertyChanged,
        .announce = announce,
        .setActionCallback = setActionCallback,
        .tick = tick,
    };

    // ========================================================================
    // Control Pattern VTables
    // ========================================================================

    // const invoke_vtable = win.IInvokeProvider.VTable{
    //     .QueryInterface = invokeQueryInterface,
    //     .AddRef = invokeAddRef,
    //     .Release = invokeRelease,
    //     .Invoke = invokeInvoke,
    // };

    // fn invokeQueryInterface(ptr: *win.IInvokeProvider, riid: *const win.GUID, ppv: *?*anyopaque) callconv(win.cc) win.HRESULT {
    //     logToFile("UIA Invoke: QueryInterface called");
    //     _ = ptr;
    //     _ = riid;
    //     ppv.* = null;
    //     return win.E_NOINTERFACE;
    // }

    // fn invokeAddRef(ptr: *win.IInvokeProvider) callconv(win.cc) win.ULONG {
    //     logToFile("UIA Invoke: AddRef called");
    //     // Get the UIAProvider from the pattern provider
    //     // const provider = getProviderFromPattern(UIAProvider, ptr);
    //     // return provider.addRef();
    // }

    // fn invokeRelease(ptr: *win.IInvokeProvider) callconv(win.cc) win.ULONG {
    //     logToFile("UIA Invoke: Release called");
    //     // const provider = getProviderFromPattern(UIAProvider, ptr);
    //     // return provider.release();
    // }

    // fn invokeInvoke(ptr: *win.IInvokeProvider) callconv(win.cc) win.HRESULT {
    //     logToFile("UIA Invoke: Invoke called");
    //     // const provider = getProviderFromPattern(UIAProvider, ptr);

    //     // // Call back to TypeScript
    //     // if (provider.uia.action_callback) |callback| {
    //     //     _ = callback(
    //     //         provider.node.id.ptr,
    //     //         provider.node.id.len,
    //     //         .invoke,
    //     //         null,
    //     //         0,
    //     //     );
    //     // }

    //     // // Raise invoked event
    //     // _ = win.uiautomationcore.UiaRaiseAutomationEvent(
    //     //     provider.asSimple(),
    //     //     win.UIA_Invoke_InvokedEventId,
    //     // );

    //     // logger.debug("UIA: Invoked '{s}'", .{provider.node.id});
    //     return win.S_OK;
    // }

    // const toggle_vtable = win.IToggleProvider.VTable{
    //     .QueryInterface = toggleQueryInterface,
    //     .AddRef = toggleAddRef,
    //     .Release = toggleRelease,
    //     .Toggle = toggleToggle,
    //     .get_ToggleState = toggleGetState,
    // };

    // fn toggleQueryInterface(ptr: *win.IToggleProvider, riid: *const win.GUID, ppv: *?*anyopaque) callconv(win.cc) win.HRESULT {
    //     logToFile("UIA Toggle: QueryInterface called");
    //     _ = ptr;
    //     _ = riid;
    //     ppv.* = null;
    //     return win.E_NOINTERFACE;
    // }

    // fn toggleAddRef(ptr: *win.IToggleProvider) callconv(win.cc) win.ULONG {
    //     logToFile("UIA Toggle: AddRef called");
    //     // const provider = getProviderFromPattern(UIAProvider, ptr);
    //     // return provider.addRef();
    //     return 1;
    // }

    // fn toggleRelease(ptr: *win.IToggleProvider) callconv(win.cc) win.ULONG {
    //     logToFile("UIA Toggle: Release called");
    //     const provider = getProviderFromPattern(UIAProvider, ptr);
    //     // return provider.release();
    //     return 1;
    // }

    // fn toggleToggle(ptr: *win.IToggleProvider) callconv(win.cc) win.HRESULT {
    //     logToFile("UIA Toggle: Toggle called");
    //     const provider = getProviderFromPattern(UIAProvider, ptr);

    //     // Call back to TypeScript
    //     if (provider.uia.action_callback) |callback| {
    //         _ = callback(
    //             provider.node.id.ptr,
    //             provider.node.id.len,
    //             .toggle,
    //             null,
    //             0,
    //         );
    //     }

    //     logger.debug("UIA: Toggled '{s}'", .{provider.node.id});
    //     return win.S_OK;
    // }

    // fn toggleGetState(ptr: *win.IToggleProvider, ret: *win.ToggleState) callconv(win.cc) win.HRESULT {
    //     logToFile("UIA Toggle: get_ToggleState called");
    //     const provider = getProviderFromPattern(UIAProvider, ptr);
    //     ret.* = if (provider.node.state.checked) .On else .Off;
    //     return win.S_OK;
    // }

    // const value_vtable = win.IValueProvider.VTable{
    //     .QueryInterface = valueQueryInterface,
    //     .AddRef = valueAddRef,
    //     .Release = valueRelease,
    //     .SetValue = valueSetValue,
    //     .get_Value = valueGetValue,
    //     .get_IsReadOnly = valueGetIsReadOnly,
    // };

    // fn valueQueryInterface(ptr: *win.IValueProvider, riid: *const win.GUID, ppv: *?*anyopaque) callconv(win.cc) win.HRESULT {
    //     logToFile("UIA Value: QueryInterface called");
    //     _ = ptr;
    //     _ = riid;
    //     ppv.* = null;
    //     return win.E_NOINTERFACE;
    // }

    // fn valueAddRef(ptr: *win.IValueProvider) callconv(win.cc) win.ULONG {
    //     logToFile("UIA Value: AddRef called");
    //     const provider = getProviderFromPattern(UIAProvider, ptr);
    //     return provider.addRef();
    // }

    // fn valueRelease(ptr: *win.IValueProvider) callconv(win.cc) win.ULONG {
    //     logToFile("UIA Value: Release called");
    //     const provider = getProviderFromPattern(UIAProvider, ptr);
    //     return provider.release();
    // }

    // fn valueSetValue(ptr: *win.IValueProvider, value: win.LPCWSTR) callconv(win.cc) win.HRESULT {
    //     logToFile("UIA Value: SetValue called");
    //     const provider = getProviderFromPattern(UIAProvider, ptr);

    //     // Convert wide string to UTF-8
    //     // For now, just call back with the action
    //     if (provider.uia.action_callback) |callback| {
    //         // TODO: Convert value to UTF-8
    //         _ = value;
    //         _ = callback(
    //             provider.node.id.ptr,
    //             provider.node.id.len,
    //             .set_value,
    //             null,
    //             0,
    //         );
    //     }

    //     return win.S_OK;
    // }

    // fn valueGetValue(ptr: *win.IValueProvider, ret: *win.BSTR) callconv(win.cc) win.HRESULT {
    //     logToFile("UIA Value: get_Value called");
    //     const provider = getProviderFromPattern(UIAProvider, ptr);

    //     if (provider.node.value) |value| {
    //         ret.* = win.createBstr(provider.uia.allocator, value) catch null;
    //     } else {
    //         ret.* = null;
    //     }

    //     return win.S_OK;
    // }

    // fn valueGetIsReadOnly(ptr: *win.IValueProvider, ret: *win.BOOL) callconv(win.cc) win.HRESULT {
    //     logToFile("UIA Value: get_IsReadOnly called");
    //     const provider = getProviderFromPattern(UIAProvider, ptr);
    //     ret.* = if (provider.node.state.readonly) 1 else 0;
    //     return win.S_OK;
    // }

    // fn getProviderFromPattern(comptime T: type, ptr: anytype) *T {
    //     // The pattern vtable pointer is stored in the WindowsUIA struct
    //     // We need to navigate back to the UIAProvider
    //     // This is a simplified approach - in reality we'd need proper COM aggregation
    //     _ = ptr;
    //     // For now, use the focused provider or first provider
    //     if (g_windows_uia) |uia| {
    //         if (uia.focused_provider) |focused| {
    //             return focused;
    //         }
    //         var iter = uia.providers.valueIterator();
    //         if (iter.next()) |provider_ptr| {
    //             return provider_ptr.*;
    //         }
    //     }
    //     unreachable;
    // }
};

/// Map accessibility role to UIA control type
pub fn roleToControlType(role: types.Role) u32 {
    return switch (role) {
        .button => @intCast(win.UIA_ButtonControlTypeId),
        .checkbox => @intCast(win.UIA_CheckBoxControlTypeId),
        .textbox => @intCast(win.UIA_EditControlTypeId),
        .radio => @intCast(win.UIA_RadioButtonControlTypeId),
        .combobox => @intCast(win.UIA_ComboBoxControlTypeId),
        .list => @intCast(win.UIA_ListControlTypeId),
        .list_item => @intCast(win.UIA_ListItemControlTypeId),
        .menu => @intCast(win.UIA_MenuControlTypeId),
        .menu_item => @intCast(win.UIA_MenuItemControlTypeId),
        .menu_bar => @intCast(win.UIA_MenuBarControlTypeId),
        .tab => @intCast(win.UIA_TabItemControlTypeId),
        .tab_list => @intCast(win.UIA_TabControlTypeId),
        .dialog, .window => @intCast(win.UIA_WindowControlTypeId),
        .progressbar => @intCast(win.UIA_ProgressBarControlTypeId),
        .slider => @intCast(win.UIA_SliderControlTypeId),
        .scrollbar => @intCast(win.UIA_ScrollBarControlTypeId),
        .separator => @intCast(win.UIA_SeparatorControlTypeId),
        .group, .region => @intCast(win.UIA_GroupControlTypeId),
        .image => @intCast(win.UIA_ImageControlTypeId),
        .link => @intCast(win.UIA_HyperlinkControlTypeId),
        .heading, .paragraph, .article, .document => @intCast(win.UIA_TextControlTypeId),
        .tree => @intCast(win.UIA_TreeControlTypeId),
        .tree_item => @intCast(win.UIA_TreeItemControlTypeId),
        .tab_panel => @intCast(win.UIA_PaneControlTypeId),
        .none, .alert, .grid, .grid_cell, .row, .column_header, .row_header, .tooltip, .status, .toolbar, .search, .form, .application, .custom => @intCast(win.UIA_CustomControlTypeId),
    };
}

// Tests
test "WindowsUIA role to control type mapping" {
    try std.testing.expectEqual(@as(u32, 50000), roleToControlType(.button));
    try std.testing.expectEqual(@as(u32, 50002), roleToControlType(.checkbox));
    try std.testing.expectEqual(@as(u32, 50004), roleToControlType(.textbox));
}
