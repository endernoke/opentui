//! Stub accessibility implementation
//!
//! This is a no-op implementation used on unsupported platforms.
//! It satisfies the PlatformBridge interface but does nothing.

const std = @import("std");
const platform = @import("platform.zig");
const types = @import("../types.zig");
const node_mod = @import("../node.zig");

const AccessibilityNode = node_mod.AccessibilityNode;
const PlatformBridge = platform.PlatformBridge;
const Allocator = std.mem.Allocator;

pub const StubBridge = struct {
    allocator: Allocator,
    action_callback: ?types.ActionCallback,

    const Self = @This();

    pub fn create(allocator: Allocator) !PlatformBridge {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .action_callback = null,
        };
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.allocator.destroy(self);
    }

    fn addNode(_: *anyopaque, _: *AccessibilityNode) PlatformBridge.Error!void {
        // No-op
    }

    fn updateNode(_: *anyopaque, _: *AccessibilityNode) PlatformBridge.Error!void {
        // No-op
    }

    fn removeNode(_: *anyopaque, _: *AccessibilityNode) PlatformBridge.Error!void {
        // No-op
    }

    fn notifyFocusChanged(_: *anyopaque, _: ?*AccessibilityNode) PlatformBridge.Error!void {
        // No-op
    }

    fn notifyPropertyChanged(_: *anyopaque, _: *AccessibilityNode, _: types.Property) PlatformBridge.Error!void {
        // No-op
    }

    fn announce(_: *anyopaque, _: []const u8, _: types.LiveSetting) PlatformBridge.Error!void {
        // No-op
    }

    fn setActionCallback(ctx: *anyopaque, callback: ?types.ActionCallback) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.action_callback = callback;
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
