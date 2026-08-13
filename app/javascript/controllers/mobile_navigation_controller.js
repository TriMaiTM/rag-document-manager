import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "backdrop", "toggle"]

  toggle() {
    if (this.sidebarTarget.classList.contains("sidebar--open")) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.sidebarTarget.classList.add("sidebar--open")
    this.backdropTarget.hidden = false
    this.toggleTarget.setAttribute("aria-expanded", "true")
    document.body.classList.add("navigation-open")
  }

  close() {
    this.sidebarTarget.classList.remove("sidebar--open")
    this.backdropTarget.hidden = true
    this.toggleTarget.setAttribute("aria-expanded", "false")
    document.body.classList.remove("navigation-open")
  }
}
