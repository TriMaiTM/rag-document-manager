import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.scrollToBottom()
    this.renderMath()

    this.observer = new MutationObserver(() => {
      this.scrollToBottom()
      this.renderMath()
    })
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.element.scrollTop = this.element.scrollHeight
    })
  }

  renderMath() {
    if (window.renderMathInElement) {
      window.renderMathInElement(this.element, {
        delimiters: [
          { left: "$$", right: "$$", display: true },
          { left: "$", right: "$", display: false }
        ],
        throwOnError: false
      })
    }
  }
}
