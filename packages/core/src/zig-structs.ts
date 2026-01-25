import { defineStruct, defineEnum } from "bun-ffi-structs"
import { ptr, toArrayBuffer, type Pointer } from "bun:ffi"
import { RGBA } from "./lib/RGBA"

const rgbaPackTransform = (rgba?: RGBA) => (rgba ? ptr(rgba.buffer) : null)
const rgbaUnpackTransform = (ptr?: Pointer) => (ptr ? RGBA.fromArray(new Float32Array(toArrayBuffer(ptr))) : undefined)

export const StyledChunkStruct = defineStruct([
  ["text", "char*"],
  ["text_len", "u64", { lengthOf: "text" }],
  [
    "fg",
    "pointer",
    {
      optional: true,
      packTransform: rgbaPackTransform,
      unpackTransform: rgbaUnpackTransform,
    },
  ],
  [
    "bg",
    "pointer",
    {
      optional: true,
      packTransform: rgbaPackTransform,
      unpackTransform: rgbaUnpackTransform,
    },
  ],
  ["attributes", "u32", { optional: true }],
])

export const HighlightStruct = defineStruct([
  ["start", "u32"],
  ["end", "u32"],
  ["styleId", "u32"],
  ["priority", "u8", { default: 0 }],
  ["hlRef", "u16", { default: 0 }],
])

export const LogicalCursorStruct = defineStruct([
  ["row", "u32"],
  ["col", "u32"],
  ["offset", "u32"],
])

export const VisualCursorStruct = defineStruct([
  ["visualRow", "u32"],
  ["visualCol", "u32"],
  ["logicalRow", "u32"],
  ["logicalCol", "u32"],
  ["offset", "u32"],
])

const UnicodeMethodEnum = defineEnum({ wcwidth: 0, unicode: 1 }, "u8")

export const TerminalCapabilitiesStruct = defineStruct([
  ["kitty_keyboard", "bool_u8"],
  ["kitty_graphics", "bool_u8"],
  ["rgb", "bool_u8"],
  ["unicode", UnicodeMethodEnum],
  ["sgr_pixels", "bool_u8"],
  ["color_scheme_updates", "bool_u8"],
  ["explicit_width", "bool_u8"],
  ["scaled_text", "bool_u8"],
  ["sixel", "bool_u8"],
  ["focus_tracking", "bool_u8"],
  ["sync", "bool_u8"],
  ["bracketed_paste", "bool_u8"],
  ["hyperlinks", "bool_u8"],
  ["explicit_cursor_positioning", "bool_u8"],
  ["term_name", "char*"],
  ["term_name_len", "u64", { lengthOf: "term_name" }],
  ["term_version", "char*"],
  ["term_version_len", "u64", { lengthOf: "term_version" }],
  ["term_from_xtversion", "bool_u8"],
])

export const EncodedCharStruct = defineStruct([
  ["width", "u8"],
  ["char", "u32"],
])

export const LineInfoStruct = defineStruct([
  ["starts", ["u32"]],
  ["startsLen", "u32", { lengthOf: "starts" }],
  ["widths", ["u32"]],
  ["widthsLen", "u32", { lengthOf: "widths" }],
  ["sources", ["u32"]],
  ["sourcesLen", "u32", { lengthOf: "sources" }],
  ["wraps", ["u32"]],
  ["wrapsLen", "u32", { lengthOf: "wraps" }],
  ["maxWidth", "u32"],
])

export const MeasureResultStruct = defineStruct([
  ["lineCount", "u32"],
  ["maxWidth", "u32"],
])

// Accessibility enums
const AccessibilityRoleEnum = defineEnum(
  {
    none: 0,
    button: 1,
    checkbox: 2,
    textbox: 3,
    radio: 4,
    combobox: 5,
    list: 6,
    list_item: 7,
    menu: 8,
    menu_item: 9,
    menu_bar: 10,
    tab: 11,
    tab_list: 12,
    tab_panel: 13,
    dialog: 14,
    alert: 15,
    progressbar: 16,
    slider: 17,
    scrollbar: 18,
    separator: 19,
    group: 20,
    image: 21,
    link: 22,
    heading: 23,
    paragraph: 24,
    region: 25,
    application: 26,
    window: 27,
    tree: 28,
    tree_item: 29,
    grid: 30,
    grid_cell: 31,
    row: 32,
    column_header: 33,
    row_header: 34,
    tooltip: 35,
    status: 36,
    toolbar: 37,
    search: 38,
    form: 39,
    article: 40,
    document: 41,
    custom: 255,
  },
  "u32",
)

const LiveSettingEnum = defineEnum({ off: 0, polite: 1, assertive: 2 }, "u8")
const OrientationEnum = defineEnum({ horizontal: 0, vertical: 1 }, "u8")

export const AccessibilityRectStruct = defineStruct([
  ["x", "i32"],
  ["y", "i32"],
  ["width", "u32"],
  ["height", "u32"],
])

// Accessibility NodeData struct for FFI
// Must match the layout in types.zig exactly
export const AccessibilityNodeDataStruct = defineStruct([
  // ID (required)
  ["id", "char*"],
  ["id_len", "u32", { lengthOf: "id" }],
  // Role
  ["role", AccessibilityRoleEnum],
  // Name (optional)
  ["name", "char*", { optional: true }],
  ["name_len", "u32", { lengthOf: "name" }],
  // Value (optional)
  ["value", "char*", { optional: true }],
  ["value_len", "u32", { lengthOf: "value" }],
  // Description (optional)
  ["description", "char*", { optional: true }],
  ["description_len", "u32", { lengthOf: "description" }],
  // Hint (optional)
  ["hint", "char*", { optional: true }],
  ["hint_len", "u32", { lengthOf: "hint" }],
  // Bounding rect
  ["rect_x", "i32"],
  ["rect_y", "i32"],
  ["rect_width", "u32"],
  ["rect_height", "u32"],
  // State flags (packed u32)
  ["state_flags", "u32"],
  // Parent ID (optional)
  ["parent_id", "char*", { optional: true }],
  ["parent_id_len", "u32", { lengthOf: "parent_id" }],
  // Child count
  ["child_count", "u32"],
  // Live setting
  ["live_setting", LiveSettingEnum],
  // Orientation
  ["orientation", OrientationEnum],
  // Level (heading level 1-6, 0 if not heading)
  ["level", "u8"],
  // Padding
  ["_padding", "u8"],
  // Numeric values (for sliders, progress bars)
  ["min_value", "f64"],
  ["max_value", "f64"],
  ["current_value", "f64"],
])

export const CursorStateStruct = defineStruct([
  ["x", "u32"],
  ["y", "u32"],
  ["visible", "bool_u8"],
  ["style", "u8"],
  ["blinking", "bool_u8"],
  ["r", "f32"],
  ["g", "f32"],
  ["b", "f32"],
  ["a", "f32"],
])
