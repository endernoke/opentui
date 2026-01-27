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

const AccessibilityNode = node_mod.AccessibilityNode;
const PlatformBridge = platform.PlatformBridge;
const Allocator = std.mem.Allocator;

var g_windows_uia: ?*WindowsUIA = null;

pub const WindowsUIA = struct {
    allocator: Allocator,
    action_callback: ?types.ActionCallback,

    hwnd: ?win.HWND,
    com_initialized: bool,

    initialized: bool,

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
        };

        // Store global reference for window procedure
        g_windows_uia = self;

        // Initialize Windows UIA
        self.initializeUIA() catch |err| {
            logger.warn("Failed to initialize Windows UIA: {}", .{err});
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

        // Initialize COM
        const hr = win.ole32.CoInitializeEx(null, win.COINIT_APARTMENTTHREADED);
        if (win.FAILED(hr)) {
            logger.err("Failed to initialize COM: 0x{X}", .{@as(u32, @bitCast(hr))});
            return error.InitializationFailed;
        }
        logger.debug("COM initialized for Windows UIA: 0x{X}", .{@as(u32, @bitCast(hr))});
        self.com_initialized = true;

        // Register window class
        const wc = win.WNDCLASSEXW{
            .lpfnWndProc = windowProc,
            .hInstance = win.kernel32.GetModuleHandleW(null),
            .lpszClassName = CLASS_NAME,
            .hCursor = win.user32.LoadCursorW(null, win.IDC_ARROW),
            .hbrBackground = @ptrFromInt(@intFromPtr(win.COLOR_WINDOW) + 1),
        };

        if (win.user32.RegisterClassExW(&wc) == 0) {
            logger.err("Failed to register UIA host window class", .{});
            win.ole32.CoUninitialize();
            return error.InitializationFailed;
        }
        logger.debug("Registered UIA host window class", .{});

        // Create hidden window for hosting UIA providers
        self.hwnd = win.user32.CreateWindowExW(
            // win.WS_EX_TOOLWINDOW | win.WS_EX_NOACTIVATE, // Extended styles - toolwindow doesn't show in taskbar
            0,
            CLASS_NAME,
            std.unicode.utf8ToUtf16LeStringLiteral("OpenTUI Accessibility"),
            // win.WS_POPUP | win.WS_DISABLED, // Popup window, disabled
            win.WS_OVERLAPPEDWINDOW,
            100,
            100,
            100,
            100,
            null, // No parent
            null, // No menu
            win.kernel32.GetModuleHandleW(null),
            null, // No param
        );

        if (self.hwnd == null) {
            logger.err("Failed to create UIA host window", .{});
            win.ole32.CoUninitialize();
            return error.InitializationFailed;
        }

        const hwnd = self.hwnd.?;
        _ = win.user32.ShowWindow(hwnd, 1);
        _ = win.user32.UpdateWindow(hwnd);

        logger.info("Windows UIA accessibility bridge initialized (hwnd={*})", .{self.hwnd});
        self.initialized = true;
    }

    fn windowProc(hwnd: win.HWND, msg: win.UINT, wParam: win.WPARAM, lParam: win.LPARAM) callconv(win.cc) win.LRESULT {
        switch (msg) {
            win.WM_DESTROY => {
                _ = win.user32.PostQuitMessage(0);
                return 0;
            },
            else => {
                return win.user32.DefWindowProcW(hwnd, msg, wParam, lParam);
            },
        }
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (builtin.os.tag != .windows) {
            self.allocator.destroy(self);
            return;
        }

        if (self.hwnd) |hwnd| {
            _ = win.user32.DestroyWindow(hwnd);
        }

        if (self.com_initialized) {
            win.ole32.CoUninitialize();
        }

        // Clear global reference
        g_windows_uia = null;

        self.allocator.destroy(self);
    }

    fn addNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        // TODO
        logger.debug("UIA: Added node '{s}' with role {s}", .{ node.id, node.role.name() });
    }

    fn updateNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        // TODO
        logger.debug("UIA: Updated node '{s}'", .{node.id});
    }

    fn removeNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        _ = ctx;

        // TODO
        logger.debug("UIA: Removed node '{s}'", .{node.id});
    }

    fn notifyFocusChanged(ctx: *anyopaque, node: ?*AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        // TODO
        if (node) |n| {
            logger.debug("UIA: Focus changed to node '{s}'", .{n.id});
        } else {
            logger.debug("UIA: Focus cleared", .{});
        }
    }

    fn notifyPropertyChanged(ctx: *anyopaque, node: *AccessibilityNode, property: types.Property) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        // TODO: Call UiaRaiseAutomationPropertyChangedEvent with appropriate property ID
        logger.debug("UIA: Property '{s}' changed for node '{s}'", .{ @tagName(property), node.id });
    }

    fn announce(ctx: *anyopaque, message: []const u8, priority: types.LiveSetting) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        // TODO

        const priority_str = switch (priority) {
            .off => "off",
            .polite => "polite",
            .assertive => "assertive",
        };
        logger.debug("UIA: Announce ({s}): {s}", .{ priority_str, message });
    }

    fn setActionCallback(ctx: *anyopaque, callback: ?types.ActionCallback) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.action_callback = callback;
    }

    // This function is called in each rendering iteration
    pub fn tick(ctx: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized or self.hwnd == null) return;

        var msg: win.MSG = undefined;
        // We use PeekMessage here instead of GetMessage to avoid blocking
        while (win.user32.PeekMessageW(&msg, self.hwnd.?, 0, 0, win.PM_REMOVE) != 0) {
            if (msg.message == win.WM_QUIT) {
                logger.info("UIA host window received WM_QUIT", .{});
                break;
            }
            _ = win.user32.TranslateMessage(&msg);
            _ = win.user32.DispatchMessageW(&msg);
        }
    }

    /// Map accessibility role to UIA control type
    pub fn roleToControlType(role: types.Role) u32 {
        // UIA Control Type IDs
        const UIA_ButtonControlTypeId: u32 = 50000;
        const UIA_CheckBoxControlTypeId: u32 = 50002;
        const UIA_ComboBoxControlTypeId: u32 = 50003;
        const UIA_EditControlTypeId: u32 = 50004;
        const UIA_HyperlinkControlTypeId: u32 = 50005;
        const UIA_ImageControlTypeId: u32 = 50006;
        const UIA_ListItemControlTypeId: u32 = 50007;
        const UIA_ListControlTypeId: u32 = 50008;
        const UIA_MenuControlTypeId: u32 = 50009;
        const UIA_MenuBarControlTypeId: u32 = 50010;
        const UIA_MenuItemControlTypeId: u32 = 50011;
        const UIA_ProgressBarControlTypeId: u32 = 50012;
        const UIA_RadioButtonControlTypeId: u32 = 50013;
        const UIA_ScrollBarControlTypeId: u32 = 50014;
        const UIA_SliderControlTypeId: u32 = 50015;
        const UIA_TabControlTypeId: u32 = 50018;
        const UIA_TabItemControlTypeId: u32 = 50019;
        const UIA_TextControlTypeId: u32 = 50020;
        const UIA_TreeControlTypeId: u32 = 50023;
        const UIA_TreeItemControlTypeId: u32 = 50024;
        const UIA_CustomControlTypeId: u32 = 50025;
        const UIA_GroupControlTypeId: u32 = 50026;
        const UIA_WindowControlTypeId: u32 = 50032;
        const UIA_PaneControlTypeId: u32 = 50033;
        const UIA_SeparatorControlTypeId: u32 = 50038;

        return switch (role) {
            .button => UIA_ButtonControlTypeId,
            .checkbox => UIA_CheckBoxControlTypeId,
            .textbox => UIA_EditControlTypeId,
            .radio => UIA_RadioButtonControlTypeId,
            .combobox => UIA_ComboBoxControlTypeId,
            .list => UIA_ListControlTypeId,
            .list_item => UIA_ListItemControlTypeId,
            .menu => UIA_MenuControlTypeId,
            .menu_item => UIA_MenuItemControlTypeId,
            .menu_bar => UIA_MenuBarControlTypeId,
            .tab => UIA_TabItemControlTypeId,
            .tab_list => UIA_TabControlTypeId,
            .dialog, .window => UIA_WindowControlTypeId,
            .progressbar => UIA_ProgressBarControlTypeId,
            .slider => UIA_SliderControlTypeId,
            .scrollbar => UIA_ScrollBarControlTypeId,
            .separator => UIA_SeparatorControlTypeId,
            .group, .region => UIA_GroupControlTypeId,
            .image => UIA_ImageControlTypeId,
            .link => UIA_HyperlinkControlTypeId,
            .heading, .paragraph, .article, .document => UIA_TextControlTypeId,
            .tree => UIA_TreeControlTypeId,
            .tree_item => UIA_TreeItemControlTypeId,
            .tab_panel => UIA_PaneControlTypeId,
            .none, .alert, .grid, .grid_cell, .row, .column_header, .row_header, .tooltip, .status, .toolbar, .search, .form, .application, .custom => UIA_CustomControlTypeId,
        };
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
};

// Tests
test "WindowsUIA role to control type mapping" {
    try std.testing.expectEqual(@as(u32, 50000), WindowsUIA.roleToControlType(.button));
    try std.testing.expectEqual(@as(u32, 50002), WindowsUIA.roleToControlType(.checkbox));
    try std.testing.expectEqual(@as(u32, 50004), WindowsUIA.roleToControlType(.textbox));
}
