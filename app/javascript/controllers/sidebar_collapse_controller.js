import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["shell", "sidebar", "toggle"]

  connect() {
    if (window.localStorage.getItem("codexys-sidebar-collapsed") === "true") {
      this.collapse()
    }
  }

  toggle() {
    if (this.shellTarget.classList.contains("app-shell--collapsed")) {
      this.expand()
    } else {
      this.collapse()
    }
  }

  collapse() {
    this.shellTarget.classList.add("app-shell--collapsed")
    this.toggleTargets.forEach(t => {
      t.setAttribute("aria-expanded", "false")
      t.setAttribute("aria-label", "Mở thanh điều hướng")
    })
    window.localStorage.setItem("codexys-sidebar-collapsed", "true")
  }

  expand() {
    this.shellTarget.classList.remove("app-shell--collapsed")
    this.toggleTargets.forEach(t => {
      t.setAttribute("aria-expanded", "true")
      t.setAttribute("aria-label", "Thu gọn thanh điều hướng")
    })
    window.localStorage.setItem("codexys-sidebar-collapsed", "false")
  }
}
