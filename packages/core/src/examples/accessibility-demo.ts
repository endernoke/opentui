#!/usr/bin/env bun

import {
  createCliRenderer,
  BoxRenderable,
  InputRenderable,
  SelectRenderable,
  TextRenderable,
  InputRenderableEvents,
  RenderableEvents,
  type CliRenderer,
  type KeyEvent,
  t,
  bold,
  fg,
  RGBA,
  type SelectOption,
} from "../index"
import { setupCommonDemoKeys } from "./lib/standalone-keys"

let renderer: CliRenderer | null = null
let nameInput: InputRenderable | null = null
let emailInput: InputRenderable | null = null
let roleSelect: SelectRenderable | null = null
let submitButton: BoxRenderable | null = null
let statusDisplay: TextRenderable | null = null
let accessibilityInfoDisplay: TextRenderable | null = null

const focusableElements: Array<InputRenderable | SelectRenderable | BoxRenderable> = []
let currentFocusIndex = 0

const roleOptions: SelectOption[] = [
  { name: "Developer", description: "Software developer role", value: "dev" },
  { name: "Designer", description: "UI/UX designer role", value: "design" },
  { name: "Manager", description: "Project manager role", value: "mgr" },
  { name: "Tester", description: "QA tester role", value: "qa" },
]

function updateAccessibilityInfo() {
  if (!renderer || !accessibilityInfoDisplay) return

  const nodes = renderer.accessibility?.getNodes()
  if (!nodes) return

  // Get focused node
  let focusedNodeInfo = "None"
  for (const [id, node] of nodes) {
    if (node.focused) {
      focusedNodeInfo = `${node.role}: "${node.label || id}"`
      break
    }
  }

  // Count nodes by role
  const roleCounts: Record<string, number> = {}
  for (const [, node] of nodes) {
    roleCounts[node.role] = (roleCounts[node.role] || 0) + 1
  }

  // Build accessibility tree summary
  const roleList = Object.entries(roleCounts)
    .map(([role, count]) => `  ${role}: ${count}`)
    .join("\n")

  const infoText = t`${bold(fg("#FFAA00")("Accessibility Information:"))}

${bold(fg("#00FFFF")("Total Nodes:"))} ${nodes.size}

${bold(fg("#00FFFF")("Nodes by Role:"))}
${fg("#CCCCCC")(roleList)}

${bold(fg("#00FFFF")("Currently Focused:"))}
${fg("#00FF00")(focusedNodeInfo)}

${bold(fg("#FFCC00")("Live Region Updates:"))}
${fg("#CCCCCC")("Status messages will announce changes")}

${bold(fg("#888888")("Note: Native screen reader support (Phase 2+)"))}
`

  accessibilityInfoDisplay.content = infoText
}

function updateStatusDisplay() {
  if (!statusDisplay || !nameInput || !emailInput || !roleSelect) return

  const nameValue = nameInput.value || ""
  const emailValue = emailInput.value || ""
  const selectedRole = roleSelect.getSelectedOption()
  const roleValue = selectedRole?.name || "Not selected"

  const statusText = t`${bold(fg("#FFFFFF")("Form Values:"))}

${bold(fg("#00FFFF")("Name:"))} ${fg("#FFFF00")(nameValue || "(empty)")}
${bold(fg("#00FFFF")("Email:"))} ${fg("#FFFF00")(emailValue || "(empty)")}
${bold(fg("#00FFFF")("Role:"))} ${fg("#FFFF00")(roleValue)}

${bold(fg("#FFFFFF")("Focus State:"))}
Name: ${nameInput.focused ? fg("#00FF00")("FOCUSED") : fg("#FF0000")("BLURRED")}
Email: ${emailInput.focused ? fg("#00FF00")("FOCUSED") : fg("#FF0000")("BLURRED")}
Role: ${roleSelect.focused ? fg("#00FF00")("FOCUSED") : fg("#FF0000")("BLURRED")}

${bold(fg("#888888")("Use Tab to navigate • Enter on button to submit"))}
`

  statusDisplay.content = statusText
}

function updateFocus(): void {
  // Blur all focusable elements first
  focusableElements.forEach((element) => element.blur())

  // Focus the current element
  const current = focusableElements[currentFocusIndex]
  if (current) {
    current.focus()
  }

  // Update displays
  updateStatusDisplay()
  updateAccessibilityInfo()
}

function handleKeyPress(key: KeyEvent): void {
  if (key.name === "tab") {
    if (key.shift) {
      currentFocusIndex = (currentFocusIndex - 1 + focusableElements.length) % focusableElements.length
    } else {
      currentFocusIndex = (currentFocusIndex + 1) % focusableElements.length
    }
    updateFocus()
  } else if (key.name === "return" || key.name === "enter") {
    // If submit button is focused, trigger the click event
    if (focusableElements[currentFocusIndex] === submitButton) {
      submitButton?.emit("click")
    }
  }
}

export function run(rendererInstance: CliRenderer): void {
  renderer = rendererInstance
  renderer.setBackgroundColor("#001122")
  renderer.start()

  // Show console to display accessibility logs
  renderer.console.show()

  console.log("=".repeat(60))
  console.log("Accessibility Demo Started")
  console.log("=".repeat(60))
  console.log("This demo showcases the TypeScript accessibility foundation.")
  console.log("Features demonstrated:")
  console.log("  • Accessibility node tracking")
  console.log("  • Focus change notifications")
  console.log("  • Property updates (labels, values, states)")
  console.log("  • Live regions")
  console.log("  • Announcements")
  console.log("  • Accessibility tree structure")
  console.log("")
  console.log("Note: Native screen reader integration (Phase 2+) not yet implemented")
  console.log("=".repeat(60))

  // Main container
  const mainContainer = new BoxRenderable(renderer, {
    id: "main-container",
    position: "absolute",
    left: 2,
    top: 2,
    width: Math.floor(renderer.width * 0.4),
    height: renderer.height - 4,
    flexDirection: "column",
    gap: 1,
    padding: 1,
    border: true,
    borderStyle: "rounded",
    borderColor: "#4488FF",
    title: "Accessibility Demo Form",
    accessibilityRole: "region",
    accessibilityLabel: "Demo Form Container",
  })
  renderer.root.add(mainContainer)

  // Title
  const title = new TextRenderable(renderer, {
    content: t`${bold(fg("#FFAA00")("Accessibility Demo"))}`,
    accessibilityRole: "heading",
    accessibilityLevel: 1,
    accessibilityLabel: "Accessibility Demo Title",
  })
  mainContainer.add(title)

  // Description
  const description = new TextRenderable(renderer, {
    content: "Fill out the form below. Check the console for accessibility events.",
    accessibilityRole: "paragraph",
  })
  mainContainer.add(description)

  // Name Input
  const nameLabel = new TextRenderable(renderer, {
    content: t`${fg("#00FFFF")("Name:")}`,
  })
  mainContainer.add(nameLabel)

  nameInput = new InputRenderable(renderer, {
    id: "name-input",
    placeholder: "Enter your name",
    accessibilityLabel: "Name Input Field",
    accessibilityHint: "Type your full name here",
  })
  mainContainer.add(nameInput)

  // Email Input
  const emailLabel = new TextRenderable(renderer, {
    content: t`${fg("#00FFFF")("Email:")}`,
  })
  mainContainer.add(emailLabel)

  emailInput = new InputRenderable(renderer, {
    id: "email-input",
    placeholder: "Enter your email",
    accessibilityLabel: "Email Input Field",
    accessibilityHint: "Type your email address",
  })
  mainContainer.add(emailInput)

  // Role Select
  const roleLabel = new TextRenderable(renderer, {
    content: t`${fg("#00FFFF")("Role:")}`,
  })
  mainContainer.add(roleLabel)

  roleSelect = new SelectRenderable(renderer, {
    id: "role-select",
    options: roleOptions,
    maxVisibleOptions: 4,
    accessibilityLabel: "Role Selection Dropdown",
    accessibilityHint: "Select your role from the list",
  })
  mainContainer.add(roleSelect)

  // Submit Button
  submitButton = new BoxRenderable(renderer, {
    id: "submit-button",
    width: 20,
    height: 3,
    justifyContent: "center",
    alignItems: "center",
    border: true,
    borderStyle: "rounded",
    borderColor: "#00FF00",
    backgroundColor: "#003300",
    accessibilityRole: "button",
    accessibilityLabel: "Submit Form Button",
    accessibilityHint: "Press Enter to submit the form",
  })

  const buttonText = new TextRenderable(renderer, {
    content: t`${bold(fg("#00FF00")("Submit"))}`,
  })
  submitButton.add(buttonText)
  mainContainer.add(submitButton)

  // Populate focusable elements array
  focusableElements.push(nameInput, emailInput, roleSelect, submitButton)

  // Status Display (right side)
  statusDisplay = new TextRenderable(renderer, {
    id: "status-display",
    position: "absolute",
    left: Math.floor(renderer.width * 0.45),
    top: 2,
    width: Math.floor(renderer.width * 0.25),
    content: "",
  })
  renderer.root.add(statusDisplay)

  // Accessibility Info Display (far right)
  accessibilityInfoDisplay = new TextRenderable(renderer, {
    id: "accessibility-info",
    position: "absolute",
    left: Math.floor(renderer.width * 0.72),
    top: 2,
    width: Math.floor(renderer.width * 0.26),
    content: "",
  })
  renderer.root.add(accessibilityInfoDisplay)

  // Event listeners
  nameInput.on(InputRenderableEvents.INPUT, () => {
    updateStatusDisplay()
    console.log(`[Accessibility] Name input value changed: "${nameInput!.value}"`)
  })

  nameInput.on(RenderableEvents.FOCUSED, () => {
    updateStatusDisplay()
    updateAccessibilityInfo()
    console.log("[Accessibility] Name input focused")
  })

  nameInput.on(RenderableEvents.BLURRED, () => {
    updateStatusDisplay()
    updateAccessibilityInfo()
    console.log("[Accessibility] Name input blurred")
  })

  emailInput.on(InputRenderableEvents.INPUT, () => {
    updateStatusDisplay()
    console.log(`[Accessibility] Email input value changed: "${emailInput!.value}"`)
  })

  emailInput.on(RenderableEvents.FOCUSED, () => {
    updateStatusDisplay()
    updateAccessibilityInfo()
    console.log("[Accessibility] Email input focused")
  })

  emailInput.on(RenderableEvents.BLURRED, () => {
    updateStatusDisplay()
    updateAccessibilityInfo()
    console.log("[Accessibility] Email input blurred")
  })

  roleSelect.on(RenderableEvents.FOCUSED, () => {
    updateStatusDisplay()
    updateAccessibilityInfo()
    console.log("[Accessibility] Role select focused")
  })

  roleSelect.on(RenderableEvents.BLURRED, () => {
    updateStatusDisplay()
    updateAccessibilityInfo()
    console.log("[Accessibility] Role select blurred")
  })

  submitButton.on("click", () => {
    const name = nameInput?.value || ""
    const email = emailInput?.value || ""
    const role = roleSelect?.getSelectedOption()?.name || "Not selected"

    console.log("")
    console.log("=".repeat(60))
    console.log("[Accessibility] FORM SUBMITTED")
    console.log("=".repeat(60))
    console.log(`Name: ${name}`)
    console.log(`Email: ${email}`)
    console.log(`Role: ${role}`)
    console.log("")

    // Announce to screen reader (Phase 2+ will actually speak this)
    renderer?.accessibility?.announce("Form submitted successfully!", "assertive")
    console.log('[Accessibility] Announcement (assertive): "Form submitted successfully!"')
    console.log("")

    // Log accessibility tree
    const tree = renderer?.accessibility?.buildTree()
    if (tree) {
      console.log("Accessibility Tree Structure:")
      logAccessibilityTree(tree, 0)
    }
    console.log("=".repeat(60))
  })

  // Listen for accessibility events
  if (renderer.accessibility) {
    renderer.accessibility.on("focus-changed", (nodeId?: string) => {
      if (nodeId) {
        const node = renderer!.accessibility!.getNode(nodeId)
        console.log(`[Accessibility Event] Focus changed to: ${node?.role} "${node?.label || nodeId}"`)
      } else {
        console.log("[Accessibility Event] Focus cleared")
      }
    })

    renderer.accessibility.on("property-changed", (nodeId: string, property: string, value: any) => {
      console.log(`[Accessibility Event] Property changed on ${nodeId}: ${property} = ${JSON.stringify(value)}`)
    })

    renderer.accessibility.on("announcement", (message: string, priority: string) => {
      console.log(`[Accessibility Event] Announcement (${priority}): "${message}"`)
    })
  }

  // Set up keyboard event handler for Tab navigation
  renderer.keyInput.on("keypress", handleKeyPress)

  // Initial updates
  updateStatusDisplay()
  updateAccessibilityInfo()
  updateFocus() // Focus first element on start

  // Log initial tree
  console.log("")
  console.log("Initial Accessibility Tree:")
  const initialTree = renderer.accessibility?.buildTree()
  if (initialTree) {
    logAccessibilityTree(initialTree, 0)
  }
  console.log("")
}

function logAccessibilityTree(node: any, depth: number): void {
  const indent = "  ".repeat(depth)
  const label = node.label ? ` "${node.label}"` : ""
  const value = node.value ? ` [value: "${node.value}"]` : ""
  const focused = node.focused ? " [FOCUSED]" : ""
  console.log(`${indent}• ${node.role}${label}${value}${focused}`)

  if (node.children) {
    for (const child of node.children) {
      logAccessibilityTree(child, depth + 1)
    }
  }
}

export function destroy(rendererInstance: CliRenderer): void {
  // Clean up keyboard event listener
  rendererInstance.keyInput.off("keypress", handleKeyPress)

  renderer = null
  nameInput = null
  emailInput = null
  roleSelect = null
  submitButton = null
  statusDisplay = null
  accessibilityInfoDisplay = null
  focusableElements.length = 0
  currentFocusIndex = 0
}

if (import.meta.main) {
  const renderer = await createCliRenderer({
    exitOnCtrlC: true,
    accessibility: { enabled: true },
  })
  run(renderer)
  setupCommonDemoKeys(renderer)
}
