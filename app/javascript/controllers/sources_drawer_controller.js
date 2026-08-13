import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["layout", "panel", "content", "template", "button"]

  connect() {
    this.close()
  }

  open(event) {
    const messageId = event.currentTarget.dataset.messageId
    const template = this.templateTargets.find((item) => (
      item.dataset.messageId === messageId
    ))

    if (!template) return

    this.contentTarget.replaceChildren(template.content.cloneNode(true))
    this.panelTarget.hidden = false
    this.layoutTarget.classList.add("chat-layout--sources-open")

    this.buttonTargets.forEach((button) => {
      button.setAttribute(
        "aria-expanded",
        button === event.currentTarget ? "true" : "false"
      )
    })

    requestAnimationFrame(() => {
      this.panelTarget.querySelector("[data-sources-close]")?.focus()
    })
  }

  close() {
    if (!this.hasPanelTarget) return

    this.panelTarget.hidden = true
    this.layoutTarget.classList.remove("chat-layout--sources-open")

    if (this.hasContentTarget) this.contentTarget.replaceChildren()

    this.buttonTargets.forEach((button) => {
      button.setAttribute("aria-expanded", "false")
    })
  }
}
