//! Accessibility types for OpenTUI
//!
//! This module defines the common types used across all platform accessibility implementations.
//! Types are designed to be FFI-compatible with C ABI for TypeScript integration.

const std = @import("std");

/// Accessibility role types (unified across platforms)
/// Maps to ARIA roles and platform-specific control types
pub const Role = enum(u32) {
    none = 0,
    button = 1,
    checkbox = 2,
    textbox = 3,
    radio = 4,
    combobox = 5,
    list = 6,
    list_item = 7,
    menu = 8,
    menu_item = 9,
    menu_bar = 10,
    tab = 11,
    tab_list = 12,
    tab_panel = 13,
    dialog = 14,
    alert = 15,
    progressbar = 16,
    slider = 17,
    scrollbar = 18,
    separator = 19,
    group = 20,
    image = 21,
    link = 22,
    heading = 23,
    paragraph = 24,
    region = 25,
    application = 26,
    window = 27,
    tree = 28,
    tree_item = 29,
    grid = 30,
    grid_cell = 31,
    row = 32,
    column_header = 33,
    row_header = 34,
    tooltip = 35,
    status = 36,
    toolbar = 37,
    search = 38,
    form = 39,
    article = 40,
    document = 41,
    custom = 255,

    /// Convert role to string name for debugging
    pub fn name(self: Role) []const u8 {
        return @tagName(self);
    }
};

/// State flags (packed struct for efficient storage)
/// Can be combined using bitwise operations
pub const StateFlags = packed struct(u32) {
    checked: bool = false,
    selected: bool = false,
    expanded: bool = false,
    disabled: bool = false,
    readonly: bool = false,
    required: bool = false,
    invalid: bool = false,
    pressed: bool = false,
    focusable: bool = false,
    focused: bool = false,
    hidden: bool = false,
    busy: bool = false,
    modal: bool = false,
    multiselectable: bool = false,
    _reserved: u18 = 0,

    pub fn toU32(self: StateFlags) u32 {
        return @bitCast(self);
    }

    pub fn fromU32(value: u32) StateFlags {
        return @bitCast(value);
    }
};

/// Live region setting for announcements
pub const LiveSetting = enum(u8) {
    off = 0,
    polite = 1,
    assertive = 2,
};

/// Orientation for controls like sliders and scrollbars
pub const Orientation = enum(u8) {
    horizontal = 0,
    vertical = 1,
};

/// Bounding rectangle in screen coordinates (character cells for TUI)
pub const Rect = extern struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,

    pub fn contains(self: Rect, px: i32, py: i32) bool {
        return px >= self.x and
            px < self.x + @as(i32, @intCast(self.width)) and
            py >= self.y and
            py < self.y + @as(i32, @intCast(self.height));
    }

    pub fn isEmpty(self: Rect) bool {
        return self.width == 0 or self.height == 0;
    }
};

/// Event type for accessibility notifications
pub const EventType = enum(u32) {
    focus_changed = 0,
    property_changed = 1,
    state_changed = 2,
    structure_changed = 3,
    announcement = 4,
    value_changed = 5,
    selection_changed = 6,
    text_changed = 7,
};

/// Property identifiers for property change events
pub const Property = enum(u32) {
    name = 0,
    value = 1,
    description = 2,
    role = 3,
    state = 4,
    bounds = 5,
    hint = 6,
    level = 7,
    min_value = 8,
    max_value = 9,
    current_value = 10,
};

/// Structure change type
pub const StructureChangeType = enum(u8) {
    child_added = 0,
    child_removed = 1,
    children_invalidated = 2,
    children_bulk_added = 3,
    children_bulk_removed = 4,
};

/// Node data structure passed from TypeScript via FFI
/// This is the external representation used for FFI calls
pub const NodeData = extern struct {
    /// Unique identifier (pointer to null-terminated string)
    id_ptr: [*]const u8,
    id_len: u32,

    /// Role of the element
    role: Role,

    /// Name/label (optional, pointer to null-terminated string)
    name_ptr: ?[*]const u8,
    name_len: u32,

    /// Current value (optional, for inputs/sliders)
    value_ptr: ?[*]const u8,
    value_len: u32,

    /// Description (optional)
    description_ptr: ?[*]const u8,
    description_len: u32,

    /// Hint text (optional)
    hint_ptr: ?[*]const u8,
    hint_len: u32,

    /// Bounding rectangle
    rect: Rect,

    /// State flags
    state_flags: StateFlags,

    /// Parent node ID (optional)
    parent_id_ptr: ?[*]const u8,
    parent_id_len: u32,

    /// Number of children
    child_count: u32,

    /// Live region setting
    live_setting: LiveSetting,

    /// Orientation (for sliders, scrollbars)
    orientation: Orientation,

    /// Heading level (1-6, 0 if not a heading)
    level: u8,

    /// Padding for alignment
    _padding: [1]u8 = .{0},

    /// Numeric value properties (for sliders, progress bars)
    min_value: f64,
    max_value: f64,
    current_value: f64,

    /// Helper to get id as slice
    pub fn getId(self: *const NodeData) []const u8 {
        return self.id_ptr[0..self.id_len];
    }

    /// Helper to get name as slice (or null)
    pub fn getName(self: *const NodeData) ?[]const u8 {
        if (self.name_ptr) |p| {
            return p[0..self.name_len];
        }
        return null;
    }

    /// Helper to get value as slice (or null)
    pub fn getValue(self: *const NodeData) ?[]const u8 {
        if (self.value_ptr) |p| {
            return p[0..self.value_len];
        }
        return null;
    }

    /// Helper to get description as slice (or null)
    pub fn getDescription(self: *const NodeData) ?[]const u8 {
        if (self.description_ptr) |p| {
            return p[0..self.description_len];
        }
        return null;
    }

    /// Helper to get hint as slice (or null)
    pub fn getHint(self: *const NodeData) ?[]const u8 {
        if (self.hint_ptr) |p| {
            return p[0..self.hint_len];
        }
        return null;
    }

    /// Helper to get parent id as slice (or null)
    pub fn getParentId(self: *const NodeData) ?[]const u8 {
        if (self.parent_id_ptr) |p| {
            return p[0..self.parent_id_len];
        }
        return null;
    }
};

/// Action types that can be performed on nodes
pub const ActionType = enum(u32) {
    invoke = 0, // Click/activate
    focus = 1, // Set focus
    set_value = 2, // Set text value
    toggle = 3, // Toggle state (checkbox/toggle button)
    expand = 4, // Expand (tree item, combobox)
    collapse = 5, // Collapse
    select = 6, // Select (list item)
    scroll_into_view = 7, // Scroll to make visible
};

/// Action request from screen reader
pub const ActionRequest = extern struct {
    node_id_ptr: [*]const u8,
    node_id_len: u32,
    action: ActionType,
    /// Optional value for set_value action
    value_ptr: ?[*]const u8,
    value_len: u32,
};

/// Callback function type for actions requested by screen readers
pub const ActionCallback = *const fn (
    node_id_ptr: [*]const u8,
    node_id_len: usize,
    action: ActionType,
    value_ptr: ?[*]const u8,
    value_len: usize,
) callconv(.c) bool;

// Tests
test "StateFlags bit operations" {
    var flags = StateFlags{};
    try std.testing.expect(!flags.checked);
    try std.testing.expect(!flags.focused);

    flags.checked = true;
    flags.focused = true;

    try std.testing.expect(flags.checked);
    try std.testing.expect(flags.focused);

    const raw = flags.toU32();
    const restored = StateFlags.fromU32(raw);
    try std.testing.expect(restored.checked);
    try std.testing.expect(restored.focused);
}

test "Rect contains" {
    const rect = Rect{ .x = 10, .y = 20, .width = 30, .height = 40 };
    try std.testing.expect(rect.contains(15, 25));
    try std.testing.expect(rect.contains(10, 20)); // Top-left corner
    try std.testing.expect(!rect.contains(40, 60)); // Just outside
    try std.testing.expect(!rect.contains(5, 25)); // Left of rect
}
