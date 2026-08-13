import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.resize()
    this.element.setAttribute("novalidate", "true")
    this.isSubmitting = false

    this.cleanupPlaceholders = () => {
      this.isSubmitting = false
      document.querySelectorAll("[data-pending-placeholder]").forEach(el => el.remove())
    }

    document.addEventListener("turbo:render", this.cleanupPlaceholders)
    document.addEventListener("turbo:load", this.cleanupPlaceholders)
  }

  disconnect() {
    if (this.cleanupPlaceholders) {
      document.removeEventListener("turbo:render", this.cleanupPlaceholders)
      document.removeEventListener("turbo:load", this.cleanupPlaceholders)
    }
  }

  resize() {
    this.inputTarget.style.height = "auto"
    this.inputTarget.style.height = `${Math.min(this.inputTarget.scrollHeight, 180)}px`
  }

  submitOnEnter(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return

    event.preventDefault()
    if (this.isSubmitting) return

    this.element.requestSubmit()
  }

  onSubmit(event) {
    const question = this.inputTarget.value.trim()
    if (!question || this.isSubmitting) {
      if (event) event.preventDefault()
      return false
    }

    this.isSubmitting = true
    this.appendOptimisticMessages(question)

    // Delay clearing input text until after form data is serialized for submission
    setTimeout(() => {
      this.inputTarget.value = ""
      this.resize()
    }, 20)
  }

  appendOptimisticMessages(question) {
    const chatThread = document.querySelector(".chat-thread")
    if (!chatThread) return

    const now = new Date()
    const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false })
    const userInitial = window.currentUserInitial || 'U'
    const logoUrl = window.codexysLogoUrl || '/assets/codexys/logo.png'

    // User Message (RIGHT)
    const userMsgHtml = `
      <article class="chat-message chat-message--user" data-pending-placeholder="true">
        <header class="chat-message__header">
          <span class="chat-message__avatar chat-message__avatar--user">${this.escapeHtml(userInitial)}</span>
          <div>
            <h2>Bạn</h2>
            <time>${timeStr}</time>
          </div>
        </header>
        <div class="chat-message__content">
          <div class="answer-copy"><p>${this.escapeHtml(question)}</p></div>
        </div>
      </article>
    `

    // Codexys Thinking Message (RIGHT)
    const assistantMsgHtml = `
      <article class="chat-message chat-message--assistant" data-pending-placeholder="true">
        <header class="chat-message__header">
          <span class="chat-message__avatar chat-message__avatar--assistant">
            <img src="${logoUrl}" alt="Codexys" class="chat-avatar-logo">
          </span>
          <div>
            <h2>Codexys</h2>
            <time>${timeStr}</time>
          </div>
        </header>
        <div class="chat-message__content">
          <div class="answer-loading" role="status" style="display: flex; align-items: center; gap: 8px;">
            <span class="spinner-ring spinner-ring--dark spinner-ring--sm"></span>
            <span>Codexys đang đọc các tài liệu...</span>
          </div>
        </div>
      </article>
    `

    chatThread.insertAdjacentHTML("beforeend", userMsgHtml + assistantMsgHtml)

    const chatScroll = document.querySelector(".chat-scroll")
    if (chatScroll) {
      chatScroll.scrollTop = chatScroll.scrollHeight
    }
  }

  escapeHtml(str) {
    const div = document.createElement('div')
    div.textContent = str
    return div.innerHTML
  }
}
