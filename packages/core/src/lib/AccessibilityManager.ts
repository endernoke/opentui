import { EventEmitter } from "events"
import type { Pointer } from "bun:ffi"
import type { AccessibilityRole, AccessibilityState, Renderable } from "../Renderable"
import type { RenderContext } from "../types"
import type {
  RenderLib,
  AccessibilityNodeData,
  AccessibilityProperty,
  FFIAccessibilityRole,
  AccessibilityStateFlags,
} from "../zig"

export interface AccessibilityNode {
  id: string
  role: AccessibilityRole
  label?: string
  value?: string
  hint?: string
  description?: string
  hidden: boolean
  live: "off" | "polite" | "assertive"
  state: AccessibilityState
  level?: number
  min?: number
  max?: number
  orientation?: "horizontal" | "vertical"

  // Layout information
  boundingRect: { x: number; y: number; width: number; height: number }

  // Tree structure
  parentId?: string
  childrenIds: string[]

  // Focus
  focusable: boolean
  focused: boolean
}

export interface AccessibilityTreeNode extends AccessibilityNode {
  children: AccessibilityTreeNode[]
}

export interface AccessibilityBridge {
  addNode(node: AccessibilityNode): void
  removeNode(nodeId: string): void
  updateNode(nodeId: string, node: AccessibilityNode): void
  notifyPropertyChanged(nodeId: string, property: string, value: any): void
  notifyFocusChanged(nodeId?: string): void
  announce(message: string, priority: "polite" | "assertive"): void
  destroy(): void
}

// Native bridge implementation that wraps the Zig FFI
class NativeAccessibilityBridge implements AccessibilityBridge {
  private bridgePtr: Pointer | null = null
  private lib: RenderLib
  private manager: AccessibilityManager

  constructor(lib: RenderLib, manager: AccessibilityManager) {
    this.lib = lib
    this.manager = manager
    this.bridgePtr = lib.accessibilityCreateBridge()

    if (this.bridgePtr) {
      // Set up action callback
      lib.accessibilitySetActionCallback(this.bridgePtr, (nodeId, action, value) => {
        return this.manager.performAction(nodeId, action, value ? { value } : undefined)
      })
    }
  }

  get isInitialized(): boolean {
    return this.bridgePtr !== null
  }

  addNode(node: AccessibilityNode): void {
    if (!this.bridgePtr) return

    const nodeData = this.nodeToFFIData(node)
    this.lib.accessibilityUpsertNode(this.bridgePtr, nodeData)
  }

  removeNode(nodeId: string): void {
    if (!this.bridgePtr) return
    this.lib.accessibilityRemoveNode(this.bridgePtr, nodeId)
  }

  updateNode(nodeId: string, node: AccessibilityNode): void {
    if (!this.bridgePtr) return
    const nodeData = this.nodeToFFIData(node)
    this.lib.accessibilityUpsertNode(this.bridgePtr, nodeData)
  }

  notifyPropertyChanged(nodeId: string, property: string, _value: any): void {
    if (!this.bridgePtr) return

    const ffiProperty = this.propertyToFFI(property)
    if (ffiProperty) {
      this.lib.accessibilityNotifyPropertyChanged(this.bridgePtr, nodeId, ffiProperty)
    }
  }

  notifyFocusChanged(nodeId?: string): void {
    if (!this.bridgePtr) return
    this.lib.accessibilitySetFocus(this.bridgePtr, nodeId ?? null)
  }

  announce(message: string, priority: "polite" | "assertive"): void {
    if (!this.bridgePtr) return
    this.lib.accessibilityAnnounce(this.bridgePtr, message, priority)
  }

  destroy(): void {
    if (this.bridgePtr) {
      this.lib.accessibilitySetActionCallback(this.bridgePtr, null)
      this.lib.accessibilityDestroyBridge(this.bridgePtr)
      this.bridgePtr = null
    }
  }

  private nodeToFFIData(node: AccessibilityNode): AccessibilityNodeData {
    return {
      id: node.id,
      role: this.roleToFFI(node.role),
      name: node.label,
      value: node.value,
      description: node.description,
      hint: node.hint,
      rect: node.boundingRect,
      state: this.stateToFFI(node.state, node.focusable, node.focused, node.hidden),
      parentId: node.parentId,
      childCount: node.childrenIds.length,
      liveSetting: node.live,
      orientation: node.orientation ?? "horizontal",
      level: node.level ?? 0,
      minValue: node.min,
      maxValue: node.max,
      currentValue: undefined, // Not tracked in current AccessibilityNode
    }
  }

  private roleToFFI(role: AccessibilityRole): FFIAccessibilityRole {
    // The role types should match between Renderable and FFI
    const roleMap: Record<string, FFIAccessibilityRole> = {
      none: "none",
      button: "button",
      checkbox: "checkbox",
      textbox: "textbox",
      radio: "radio",
      combobox: "combobox",
      list: "list",
      listitem: "list_item",
      menu: "menu",
      menuitem: "menu_item",
      menubar: "menu_bar",
      tab: "tab",
      tablist: "tab_list",
      tabpanel: "tab_panel",
      dialog: "dialog",
      alert: "alert",
      progressbar: "progressbar",
      slider: "slider",
      scrollbar: "scrollbar",
      separator: "separator",
      group: "group",
      image: "image",
      link: "link",
      heading: "heading",
      paragraph: "paragraph",
      region: "region",
      application: "application",
      window: "window",
      tree: "tree",
      treeitem: "tree_item",
      grid: "grid",
      gridcell: "grid_cell",
      row: "row",
      columnheader: "column_header",
      rowheader: "row_header",
      tooltip: "tooltip",
      status: "status",
      toolbar: "toolbar",
      search: "search",
      form: "form",
      article: "article",
      document: "document",
      custom: "custom",
    }
    return roleMap[role] ?? "none"
  }

  private stateToFFI(
    state: AccessibilityState,
    focusable: boolean,
    focused: boolean,
    hidden: boolean,
  ): AccessibilityStateFlags {
    return {
      // Convert "mixed" to true for FFI (native platforms handle mixed state differently)
      checked: state.checked === "mixed" ? true : state.checked,
      selected: state.selected,
      expanded: state.expanded,
      disabled: state.disabled,
      readonly: state.readonly,
      required: state.required,
      invalid: state.invalid,
      pressed: state.pressed,
      focusable,
      focused,
      hidden,
      busy: state.busy,
      modal: state.modal,
      multiselectable: state.multiselectable,
    }
  }

  private propertyToFFI(property: string): AccessibilityProperty | null {
    const propertyMap: Record<string, AccessibilityProperty> = {
      role: "role",
      label: "name",
      value: "value",
      description: "description",
      hint: "hint",
      state: "state",
      bounds: "bounds",
      level: "level",
      min: "min_value",
      max: "max_value",
    }
    return propertyMap[property] ?? null
  }
}

export class AccessibilityManager extends EventEmitter {
  private enabled: boolean = false
  private nodes: Map<string, AccessibilityNode> = new Map()
  private focusedNodeId?: string
  private nativeBridge?: AccessibilityBridge
  private lib?: RenderLib

  constructor(private ctx: RenderContext) {
    super()
  }

  // Set the render lib for native bridge creation
  public setRenderLib(lib: RenderLib): void {
    this.lib = lib
  }

  public setEnabled(enabled: boolean): void {
    if (enabled === this.enabled) return
    this.enabled = enabled

    if (enabled) {
      this.initialize()
    } else {
      this.shutdown()
    }
  }

  public isEnabled(): boolean {
    return this.enabled
  }

  private initialize(): void {
    // Create native bridge if we have a render lib
    if (this.lib && this.lib.accessibilityIsPlatformSupported()) {
      this.nativeBridge = new NativeAccessibilityBridge(this.lib, this)
    }

    // Traverse renderable tree and register all nodes
    this.buildAccessibilityTreeInternal(this.ctx.root)

    // Focus tracking is integrated via:
    // - renderer.focusRenderable() calls notifyFocusChanged() when focus moves
    // - renderable.blur() calls notifyFocusChanged(undefined) when focus is cleared
  }

  private shutdown(): void {
    this.nodes.clear()
    this.focusedNodeId = undefined
    this.nativeBridge?.destroy()
    this.nativeBridge = undefined
  }

  public buildTree(): AccessibilityTreeNode {
    // Rebuild tree from root
    return this.buildAccessibilityTreeNode(this.ctx.root)
  }

  private buildAccessibilityTreeNode(renderable: Renderable): AccessibilityTreeNode {
    const node = this.nodes.get(renderable.id)
    if (!node) {
      throw new Error(`Node not found for renderable ${renderable.id}`)
    }

    return {
      ...node,
      children: renderable.getChildren().map((child) => this.buildAccessibilityTreeNode(child)),
    }
  }

  private buildAccessibilityTreeInternal(renderable: Renderable): void {
    const node: AccessibilityNode = {
      id: renderable.id,
      role: renderable.accessibilityRole,
      label: renderable.accessibilityLabel,
      value: renderable.accessibilityValue,
      hint: renderable.accessibilityHint,
      description: renderable.accessibilityDescription,
      hidden: renderable.accessibilityHidden,
      live: renderable.accessibilityLive,
      state: renderable.accessibilityState,
      level: renderable.accessibilityLevel,
      min: renderable.accessibilityMin,
      max: renderable.accessibilityMax,
      orientation: renderable.accessibilityOrientation,
      boundingRect: {
        x: renderable.x,
        y: renderable.y,
        width: renderable.width,
        height: renderable.height,
      },
      parentId: renderable.parent?.id,
      childrenIds: renderable.getChildren().map((c) => c.id),
      focusable: renderable.focusable,
      focused: renderable.focused,
    }

    this.nodes.set(node.id, node)

    // Register with native bridge
    this.nativeBridge?.addNode(node)

    // Recurse to children
    for (const child of renderable.getChildren()) {
      if (child instanceof Object && "accessibilityHidden" in child) {
        this.buildAccessibilityTreeInternal(child as Renderable)
      }
    }
  }

  public addNode(renderable: Renderable): void {
    if (!this.enabled) return

    const node: AccessibilityNode = {
      id: renderable.id,
      role: renderable.accessibilityRole,
      label: renderable.accessibilityLabel,
      value: renderable.accessibilityValue,
      hint: renderable.accessibilityHint,
      description: renderable.accessibilityDescription,
      hidden: renderable.accessibilityHidden,
      live: renderable.accessibilityLive,
      state: renderable.accessibilityState,
      level: renderable.accessibilityLevel,
      min: renderable.accessibilityMin,
      max: renderable.accessibilityMax,
      orientation: renderable.accessibilityOrientation,
      boundingRect: {
        x: renderable.x,
        y: renderable.y,
        width: renderable.width,
        height: renderable.height,
      },
      parentId: renderable.parent?.id,
      childrenIds: renderable.getChildren().map((c) => c.id),
      focusable: renderable.focusable,
      focused: renderable.focused,
    }

    this.nodes.set(node.id, node)
    this.nativeBridge?.addNode(node)

    this.emit("node-added", node.id)
  }

  public removeNode(nodeId: string): void {
    if (!this.enabled) return

    const node = this.nodes.get(nodeId)
    if (!node) return

    this.nodes.delete(nodeId)
    this.nativeBridge?.removeNode(nodeId)

    this.emit("node-removed", nodeId)
  }

  public updateNode(renderable: Renderable): void {
    if (!this.enabled) return

    const node = this.nodes.get(renderable.id)
    if (!node) return

    // Update node properties
    node.role = renderable.accessibilityRole
    node.label = renderable.accessibilityLabel
    node.value = renderable.accessibilityValue
    node.hint = renderable.accessibilityHint
    node.description = renderable.accessibilityDescription
    node.hidden = renderable.accessibilityHidden
    node.live = renderable.accessibilityLive
    node.state = renderable.accessibilityState
    node.level = renderable.accessibilityLevel
    node.min = renderable.accessibilityMin
    node.max = renderable.accessibilityMax
    node.orientation = renderable.accessibilityOrientation
    node.boundingRect = {
      x: renderable.x,
      y: renderable.y,
      width: renderable.width,
      height: renderable.height,
    }
    node.parentId = renderable.parent?.id
    node.childrenIds = renderable.getChildren().map((c) => c.id)
    node.focusable = renderable.focusable
    node.focused = renderable.focused

    this.nativeBridge?.updateNode(renderable.id, node)
    this.emit("node-updated", renderable.id)
  }

  public notifyPropertyChanged(renderable: Renderable, property: string): void {
    if (!this.enabled) return

    const node = this.nodes.get(renderable.id)
    if (!node) return

    // Update the node with the new value from the renderable
    let value: any
    switch (property) {
      case "role":
        node.role = renderable.accessibilityRole
        value = node.role
        break
      case "label":
        node.label = renderable.accessibilityLabel
        value = node.label
        break
      case "value":
        node.value = renderable.accessibilityValue
        value = node.value
        break
      case "hint":
        node.hint = renderable.accessibilityHint
        value = node.hint
        break
      case "description":
        node.description = renderable.accessibilityDescription
        value = node.description
        break
      case "hidden":
        node.hidden = renderable.accessibilityHidden
        value = node.hidden
        break
      case "live":
        node.live = renderable.accessibilityLive
        value = node.live
        break
      case "state":
        node.state = renderable.accessibilityState
        value = node.state
        break
      case "level":
        node.level = renderable.accessibilityLevel
        value = node.level
        break
      case "min":
        node.min = renderable.accessibilityMin
        value = node.min
        break
      case "max":
        node.max = renderable.accessibilityMax
        value = node.max
        break
      case "orientation":
        node.orientation = renderable.accessibilityOrientation
        value = node.orientation
        break
      default:
        return
    }

    // Notify native bridge
    this.nativeBridge?.notifyPropertyChanged(renderable.id, property, value)

    this.emit("property-changed", renderable.id, property, value)
  }

  public updateNodeChildren(renderable: Renderable): void {
    if (!this.enabled) return

    const node = this.nodes.get(renderable.id)
    if (!node) return

    // Update children list
    node.childrenIds = renderable.getChildren().map((c) => c.id)
    node.parentId = renderable.parent?.id

    this.nativeBridge?.updateNode(renderable.id, node)
    this.emit("node-updated", renderable.id)
  }

  public notifyFocusChanged(nodeId?: string): void {
    if (!this.enabled) return

    // Update focused state on old and new nodes
    if (this.focusedNodeId) {
      const prevNode = this.nodes.get(this.focusedNodeId)
      if (prevNode) prevNode.focused = false
    }

    this.focusedNodeId = nodeId

    if (nodeId) {
      const node = this.nodes.get(nodeId)
      if (node) node.focused = true
    }

    // Notify native bridge
    this.nativeBridge?.notifyFocusChanged(nodeId)

    this.emit("focus-changed", nodeId)
  }

  public announce(message: string, priority: "polite" | "assertive" = "polite"): void {
    if (!this.enabled) return

    // Notify native bridge
    this.nativeBridge?.announce(message, priority)

    this.emit("announcement", message, priority)
  }

  public getNodes(): Map<string, AccessibilityNode> {
    return this.nodes
  }

  public getNode(nodeId: string): AccessibilityNode | undefined {
    return this.nodes.get(nodeId)
  }

  // Called by native bridge when screen reader requests action
  public performAction(nodeId: string, action: string, args?: any): boolean {
    const renderable = this.ctx.getRenderableById(nodeId)
    if (!renderable) return false

    switch (action) {
      case "invoke":
        // Trigger click/activation
        renderable.emit("click")
        return true

      case "focus":
        if ("focus" in renderable && typeof renderable.focus === "function") {
          renderable.focus()
          return true
        }
        return false

      case "set_value":
        // For inputs - check if renderable has a value setter
        if ("value" in renderable) {
          const descriptor = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(renderable), "value")
          if (descriptor && descriptor.set) {
            descriptor.set.call(renderable, args?.value)
            return true
          }
        }
        return false

      case "toggle":
        // For checkboxes/toggles
        if ("toggle" in renderable && typeof (renderable as any).toggle === "function") {
          ;(renderable as any).toggle()
          return true
        }
        // Fallback to click
        renderable.emit("click")
        return true

      case "expand":
        if ("expand" in renderable && typeof (renderable as any).expand === "function") {
          ;(renderable as any).expand()
          return true
        }
        return false

      case "collapse":
        if ("collapse" in renderable && typeof (renderable as any).collapse === "function") {
          ;(renderable as any).collapse()
          return true
        }
        return false

      case "select":
        if ("select" in renderable && typeof (renderable as any).select === "function") {
          ;(renderable as any).select()
          return true
        }
        return false

      case "scroll_into_view":
        if ("scrollIntoView" in renderable && typeof (renderable as any).scrollIntoView === "function") {
          ;(renderable as any).scrollIntoView()
          return true
        }
        return false

      default:
        return false
    }
  }

  // Get platform name (for debugging/diagnostics)
  public getPlatformName(): string {
    if (!this.lib) return "none"
    return this.lib.accessibilityGetPlatformName()
  }

  // Check if platform is supported
  public isPlatformSupported(): boolean {
    if (!this.lib) return false
    return this.lib.accessibilityIsPlatformSupported()
  }
}
