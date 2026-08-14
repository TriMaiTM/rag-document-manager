import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "heading", "form", "input"]
  static values = { url: String }

  connect() {
    this.isEditing = false
  }

  startEditing() {
    if (this.isEditing) return
    this.isEditing = true
    this.initialTitle = this.headingTarget.textContent.trim()
    this.displayTarget.style.display = "none"
    this.formTarget.style.display = "block"
    this.inputTarget.focus()
  }

  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.inputTarget.blur()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.cancel()
    }
  }

  cancel() {
    if (!this.isEditing) return
    this.isEditing = false
    this.inputTarget.value = this.initialTitle || this.headingTarget.textContent.trim()
    this.formTarget.style.display = "none"
    this.displayTarget.style.display = "block"
  }

  async save(event) {
    if (event) event.preventDefault()
    if (!this.isEditing) return
    this.isEditing = false

    const newTitle = this.inputTarget.value.trim()
    const currentTitle = this.initialTitle || this.headingTarget.textContent.trim()

    if (!newTitle || newTitle === currentTitle) {
      this.headingTarget.textContent = currentTitle
      this.inputTarget.value = currentTitle
      this.formTarget.style.display = "none"
      this.displayTarget.style.display = "block"
      return
    }

    // Optimistic UI update for heading and sidebar
    this.headingTarget.textContent = newTitle
    this.formTarget.style.display = "none"
    this.displayTarget.style.display = "block"

    const activeSidebarLinkSpan = document.querySelector(".workspace-chat-link--active span")
    if (activeSidebarLinkSpan) {
      activeSidebarLinkSpan.textContent = newTitle
    }

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({ chat_session: { title: newTitle } })
      })

      if (!response.ok) {
        this.headingTarget.textContent = currentTitle
        this.inputTarget.value = currentTitle
        if (activeSidebarLinkSpan) activeSidebarLinkSpan.textContent = currentTitle
      }
    } catch (error) {
      this.headingTarget.textContent = currentTitle
      this.inputTarget.value = currentTitle
      if (activeSidebarLinkSpan) activeSidebarLinkSpan.textContent = currentTitle
    }
  }
}
