import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static values = { url: String }

  prepare(event) {
    const item = event.currentTarget
    item.draggable = Boolean(event.target.closest("[data-workspace-sort-handle]"))
  }

  dragStart(event) {
    if (!event.currentTarget.draggable) {
      event.preventDefault()
      return
    }

    this.draggedItem = event.currentTarget
    this.draggedItem.classList.add("workspace-nav-item--dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedItem.dataset.workspaceId)
  }

  dragOver(event) {
    if (!this.draggedItem) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"

    const target = event.target.closest("[data-workspace-sort-target='item']")
    if (!target || target === this.draggedItem) return

    const bounds = target.getBoundingClientRect()
    const insertAfter = event.clientY > bounds.top + bounds.height / 2
    target.insertAdjacentElement(insertAfter ? "afterend" : "beforebegin", this.draggedItem)
  }

  drop(event) {
    if (!this.draggedItem) return

    event.preventDefault()
    this.persist()
  }

  dragEnd(event) {
    event.currentTarget.draggable = false
    event.currentTarget.classList.remove("workspace-nav-item--dragging")
    this.draggedItem = null
  }

  moveWithKeyboard(event) {
    if (!event.altKey || !["ArrowUp", "ArrowDown"].includes(event.key)) return

    event.preventDefault()
    const item = event.currentTarget.closest("[data-workspace-sort-target='item']")
    const sibling = event.key === "ArrowUp" ? item.previousElementSibling : item.nextElementSibling

    if (!sibling?.matches("[data-workspace-sort-target='item']")) return

    if (event.key === "ArrowUp") {
      sibling.insertAdjacentElement("beforebegin", item)
    } else {
      sibling.insertAdjacentElement("afterend", item)
    }

    this.persist()
    event.currentTarget.focus()
  }

  async persist() {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const workspaceIds = this.itemTargets.map((item) => item.dataset.workspaceId)

    const response = await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ workspace_ids: workspaceIds })
    })

    if (!response.ok) window.location.reload()
  }
}
