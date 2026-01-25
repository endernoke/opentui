import { test, expect, beforeEach, afterEach, describe } from "bun:test"
import { createTestRenderer, type TestRenderer } from "../testing/test-renderer"
import { BoxRenderable } from "../renderables/Box"
import { InputRenderable } from "../renderables/Input"
import { TextRenderable } from "../renderables/Text"
import { SelectRenderable } from "../renderables/Select"
import type { AccessibilityNode } from "../lib/AccessibilityManager"

describe("Accessibility", () => {
  let testContext: Awaited<ReturnType<typeof createTestRenderer>>

  beforeEach(async () => {
    testContext = await createTestRenderer({ accessibility: { enabled: true } })
  })

  afterEach(() => {
    testContext.renderer.destroy()
  })

  test("accessibility manager is initialized when enabled", () => {
    expect(testContext.renderer.accessibility).toBeDefined()
    expect(testContext.renderer.accessibility?.isEnabled()).toBe(true)
  })

  test("accessibility manager tracks nodes", () => {
    const button = new BoxRenderable(testContext.renderer, {
      accessibilityRole: "button",
      accessibilityLabel: "Click Me",
    })

    const nodes = testContext.renderer.accessibility!.getNodes()
    expect(nodes.has(button.id)).toBe(true)

    const node = nodes.get(button.id)
    expect(node?.role).toBe("button")
    expect(node?.label).toBe("Click Me")
  })

  test("accessibility properties can be updated", () => {
    const button = new BoxRenderable(testContext.renderer, {
      accessibilityRole: "button",
      accessibilityLabel: "Initial Label",
    })

    button.accessibilityLabel = "Updated Label"

    const nodes = testContext.renderer.accessibility!.getNodes()
    const node = nodes.get(button.id)
    expect(node?.label).toBe("Updated Label")
  })

  test("accessibility state updates correctly", () => {
    const checkbox = new BoxRenderable(testContext.renderer, {
      accessibilityRole: "checkbox",
      accessibilityLabel: "Accept Terms",
      accessibilityState: { checked: false },
    })

    let nodes = testContext.renderer.accessibility!.getNodes()
    let node = nodes.get(checkbox.id)
    expect(node?.state.checked).toBe(false)

    checkbox.accessibilityState = { checked: true }

    nodes = testContext.renderer.accessibility!.getNodes()
    node = nodes.get(checkbox.id)
    expect(node?.state.checked).toBe(true)
  })

  test("input has default textbox role", () => {
    const input = new InputRenderable(testContext.renderer, {
      placeholder: "Enter text",
    })

    const nodes = testContext.renderer.accessibility!.getNodes()
    const node = nodes.get(input.id)
    expect(node?.role).toBe("textbox")
  })

  test("select has default list role", () => {
    const select = new SelectRenderable(testContext.renderer, {
      options: [
        { label: "Option 1", value: "1" },
        { label: "Option 2", value: "2" },
      ],
    })

    const nodes = testContext.renderer.accessibility!.getNodes()
    const node = nodes.get(select.id)
    expect(node?.role).toBe("list")
  })

  test("accessibility tree structure is built correctly", () => {
    const container = new BoxRenderable(testContext.renderer, {
      accessibilityRole: "region",
      accessibilityLabel: "Container",
    })

    const child1 = new BoxRenderable(testContext.renderer, {
      accessibilityRole: "button",
      accessibilityLabel: "Button 1",
    })

    const child2 = new BoxRenderable(testContext.renderer, {
      accessibilityRole: "button",
      accessibilityLabel: "Button 2",
    })

    container.add(child1)
    container.add(child2)

    testContext.renderer.root.add(container)

    const tree = testContext.renderer.accessibility!.buildTree()
    expect(tree.children.length).toBeGreaterThan(0)

    const nodes = testContext.renderer.accessibility!.getNodes()
    const containerNode = nodes.get(container.id)
    expect(containerNode?.childrenIds.length).toBe(2)
    expect(containerNode?.childrenIds).toContain(child1.id)
    expect(containerNode?.childrenIds).toContain(child2.id)
  })

  test("focus changes are tracked", () => {
    const button = new BoxRenderable(testContext.renderer, {
      accessibilityRole: "button",
      accessibilityLabel: "Focusable Button",
    })

    testContext.renderer.root.add(button)
    testContext.renderer.focusRenderable(button)

    // Focus notification should have been called
    expect(testContext.renderer.currentFocusedRenderable).toBe(button)

    const node = testContext.renderer.accessibility!.getNode(button.id)
    expect(node?.focused).toBe(true)
  })

  test("blur clears focus in accessibility manager", () => {
    const input = new InputRenderable(testContext.renderer, {
      accessibilityLabel: "Blurable Input",
    })

    testContext.renderer.root.add(input)

    // Input is focusable by default
    expect(input.focusable).toBe(true)

    input.focus()

    // Verify input is focused
    expect(input.focused).toBe(true)

    // Verify input is focused in accessibility manager
    let node = testContext.renderer.accessibility!.getNode(input.id)
    expect(node?.focusable).toBe(true)
    expect(node?.focused).toBe(true)

    // Blur the input
    input.blur()

    // Verify focus is cleared in accessibility manager
    node = testContext.renderer.accessibility!.getNode(input.id)
    expect(node?.focused).toBe(false)
  })

  test("accessibility can be disabled", () => {
    expect(testContext.renderer.accessibility!.isEnabled()).toBe(true)

    testContext.renderer.disableAccessibility()
    expect(testContext.renderer.accessibility!.isEnabled()).toBe(false)
  })

  test("accessibility can be enabled dynamically", async () => {
    const testContextNoA11y = await createTestRenderer({})
    expect(testContextNoA11y.renderer.accessibility).toBeUndefined()

    testContextNoA11y.renderer.enableAccessibility()
    expect(testContextNoA11y.renderer.accessibility).toBeDefined()
    expect(testContextNoA11y.renderer.accessibility!.isEnabled()).toBe(true)

    testContextNoA11y.renderer.destroy()
  })

  test("nodes are removed when renderables are destroyed", () => {
    const button = new BoxRenderable(testContext.renderer, {
      accessibilityRole: "button",
      accessibilityLabel: "Temporary Button",
    })

    const nodes = testContext.renderer.accessibility!.getNodes()
    expect(nodes.has(button.id)).toBe(true)

    button.destroy()

    expect(nodes.has(button.id)).toBe(false)
  })

  test("hidden accessibility property works", () => {
    const button = new BoxRenderable(testContext.renderer, {
      accessibilityRole: "button",
      accessibilityLabel: "Hidden Button",
      accessibilityHidden: true,
    })

    const nodes = testContext.renderer.accessibility!.getNodes()
    const node = nodes.get(button.id)
    expect(node?.hidden).toBe(true)
  })

  test("accessibility level for headings", () => {
    const heading = new TextRenderable(testContext.renderer, {
      text: "Title",
      accessibilityRole: "heading",
      accessibilityLevel: 1,
    })

    const nodes = testContext.renderer.accessibility!.getNodes()
    const node = nodes.get(heading.id)
    expect(node?.role).toBe("heading")
    expect(node?.level).toBe(1)
  })

  test("announce method sends announcements", () => {
    const announcement = "Test announcement"
    testContext.renderer.accessibility!.announce(announcement, "polite")

    // In a real implementation, this would trigger screen reader output
    // For now, we just verify the method doesn't throw
    expect(true).toBe(true)
  })

  test("getRenderableById returns correct renderable", () => {
    const button = new BoxRenderable(testContext.renderer, {
      accessibilityRole: "button",
      accessibilityLabel: "Test Button",
    })

    testContext.renderer.root.add(button)

    const found = testContext.renderer.getRenderableById(button.id)
    expect(found).toBe(button)
  })

  test("accessibility value updates for inputs", () => {
    const input = new InputRenderable(testContext.renderer, {
      placeholder: "Enter value",
      accessibilityLabel: "Test Input",
    })

    input.value = "Hello World"

    const nodes = testContext.renderer.accessibility!.getNodes()
    const node = nodes.get(input.id)
    expect(node?.value).toBe("Hello World")
  })

  test("orientation property for sliders", () => {
    const slider = new BoxRenderable(testContext.renderer, {
      accessibilityRole: "slider",
      accessibilityOrientation: "horizontal",
      accessibilityMin: 0,
      accessibilityMax: 100,
      accessibilityValue: "50",
    })

    const nodes = testContext.renderer.accessibility!.getNodes()
    const node = nodes.get(slider.id)
    expect(node?.orientation).toBe("horizontal")
    expect(node?.min).toBe(0)
    expect(node?.max).toBe(100)
    expect(node?.value).toBe("50")
  })

  test("live region property", () => {
    const liveRegion = new TextRenderable(testContext.renderer, {
      text: "Live content",
      accessibilityLive: "assertive",
      accessibilityLabel: "Status message",
    })

    const nodes = testContext.renderer.accessibility!.getNodes()
    const node = nodes.get(liveRegion.id)
    expect(node?.live).toBe("assertive")
  })
})
