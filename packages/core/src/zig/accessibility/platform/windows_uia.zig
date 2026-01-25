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

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform.zig");
const types = @import("../types.zig");
const node_mod = @import("../node.zig");
const logger = @import("../../logger.zig");

const AccessibilityNode = node_mod.AccessibilityNode;
const PlatformBridge = platform.PlatformBridge;
const Allocator = std.mem.Allocator;

// Windows types (only available on Windows)
const windows = if (builtin.os.tag == .windows) @import("std").os.windows else struct {};

pub const WindowsUIA = struct {
    allocator: Allocator,
    action_callback: ?types.ActionCallback,

    // Platform-specific state (will be expanded in Phase 2.5)
    hwnd: ?*anyopaque, // HWND for hosting UIA providers
    providers: std.StringHashMap(*UIAProvider),
    root_provider: ?*UIAProvider,
    focused_node_id: ?[]const u8,

    // Initialization state
    initialized: bool,

    const Self = @This();

    /// UIA Provider wrapper for a single accessibility node
    /// This will implement COM interfaces in the full implementation
    pub const UIAProvider = struct {
        node: *AccessibilityNode,
        runtime_id: u32,
        parent: ?*UIAProvider,
        children: std.ArrayList(*UIAProvider),

        pub fn init(allocator: Allocator, node: *AccessibilityNode, runtime_id: u32) !*UIAProvider {
            const provider = try allocator.create(UIAProvider);
            provider.* = .{
                .node = node,
                .runtime_id = runtime_id,
                .parent = null,
                .children = .{},
            };
            return provider;
        }

        pub fn deinit(self: *UIAProvider, allocator: Allocator) void {
            self.children.deinit(allocator);
            allocator.destroy(self);
        }
    };

    pub fn create(allocator: Allocator) !PlatformBridge {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .action_callback = null,
            .hwnd = null,
            .providers = std.StringHashMap(*UIAProvider).init(allocator),
            .root_provider = null,
            .focused_node_id = null,
            .initialized = false,
        };

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

    /// Initialize Windows UIA infrastructure
    fn initializeUIA(self: *Self) !void {
        if (builtin.os.tag != .windows) {
            return;
        }

        // TODO: Phase 2.5 - Full Windows UIA implementation
        // 1. CoInitializeEx for COM
        // 2. Register window class for hidden host window
        // 3. Create hidden HWND (1x1, off-screen)
        // 4. Register as UIA provider host

        logger.info("Windows UIA accessibility bridge initialized", .{});
        self.initialized = true;
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        // Clean up providers
        var provider_iter = self.providers.iterator();
        while (provider_iter.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
        }
        self.providers.deinit();

        if (self.focused_node_id) |id| {
            self.allocator.free(id);
        }

        // TODO: Clean up HWND and UIA resources

        self.allocator.destroy(self);
    }

    fn addNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        // Generate runtime ID (unique within this provider tree)
        const runtime_id = @as(u32, @truncate(self.providers.count() + 1));

        // Create UIA provider for this node
        const provider = UIAProvider.init(self.allocator, node, runtime_id) catch {
            return PlatformBridge.Error.OutOfMemory;
        };

        // Store reference
        self.providers.put(node.id, provider) catch {
            provider.deinit(self.allocator);
            return PlatformBridge.Error.OutOfMemory;
        };

        // Link to parent provider if exists
        if (node.parent_id) |parent_id| {
            if (self.providers.get(parent_id)) |parent_provider| {
                provider.parent = parent_provider;
                parent_provider.children.append(self.allocator, provider) catch {
                    return PlatformBridge.Error.OutOfMemory;
                };
            }
        } else {
            // This is a root node
            self.root_provider = provider;
        }

        // Store platform data reference in node
        node.platform_data = provider;

        // TODO: Raise UIA structure changed event
        logger.debug("UIA: Added node '{s}' with role {s}", .{ node.id, node.role.name() });
    }

    fn updateNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        const provider = self.providers.get(node.id) orelse {
            return PlatformBridge.Error.NodeNotFound;
        };
        _ = provider;

        // TODO: Raise UIA property changed events for modified properties
        logger.debug("UIA: Updated node '{s}'", .{node.id});
    }

    fn removeNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        if (self.providers.fetchRemove(node.id)) |kv| {
            const provider = kv.value;

            // Remove from parent's children list
            if (provider.parent) |parent| {
                for (parent.children.items, 0..) |child, i| {
                    if (child == provider) {
                        _ = parent.children.orderedRemove(i);
                        break;
                    }
                }
            }

            // Clear root if this was the root
            if (self.root_provider == provider) {
                self.root_provider = null;
            }

            // Clean up
            provider.deinit(self.allocator);
            node.platform_data = null;

            // TODO: Raise UIA structure changed event
            logger.debug("UIA: Removed node '{s}'", .{node.id});
        }
    }

    fn notifyFocusChanged(ctx: *anyopaque, node: ?*AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        // Update tracked focus
        if (self.focused_node_id) |old_id| {
            self.allocator.free(old_id);
        }

        if (node) |n| {
            self.focused_node_id = self.allocator.dupe(u8, n.id) catch {
                return PlatformBridge.Error.OutOfMemory;
            };
            // TODO: Raise UiaRaiseFocusChangedEvent
            logger.debug("UIA: Focus changed to '{s}'", .{n.id});
        } else {
            self.focused_node_id = null;
            logger.debug("UIA: Focus cleared", .{});
        }
    }

    fn notifyPropertyChanged(ctx: *anyopaque, node: *AccessibilityNode, property: types.Property) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        const provider = self.providers.get(node.id) orelse {
            return PlatformBridge.Error.NodeNotFound;
        };
        _ = provider;

        // TODO: Call UiaRaiseAutomationPropertyChangedEvent with appropriate property ID
        logger.debug("UIA: Property '{s}' changed for node '{s}'", .{ @tagName(property), node.id });
    }

    fn announce(ctx: *anyopaque, message: []const u8, priority: types.LiveSetting) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        // TODO: Call UiaRaiseNotificationEvent
        // NotificationKind: ActionCompleted
        // NotificationProcessing: based on priority (ImportantAll for assertive, All for polite)

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
    };
};

// Tests
test "WindowsUIA role to control type mapping" {
    try std.testing.expectEqual(@as(u32, 50000), WindowsUIA.roleToControlType(.button));
    try std.testing.expectEqual(@as(u32, 50002), WindowsUIA.roleToControlType(.checkbox));
    try std.testing.expectEqual(@as(u32, 50004), WindowsUIA.roleToControlType(.textbox));
}
