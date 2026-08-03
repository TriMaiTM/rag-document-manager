import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 2000 }
  }

  connect() {
    this.connected = true
    this.scheduleRefresh()
  }

  disconnect() {
    this.connected = false
    clearTimeout(this.timeout)
    this.abortController?.abort()
  }

  scheduleRefresh() {
    if (!this.connected) return

    this.timeout = setTimeout(
      () => this.refresh(),
      this.intervalValue
    )
  }

  async refresh() {
    let continuePolling = true
    this.abortController = new AbortController()

    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: this.abortController.signal
      })

      if ([401, 403, 404].includes(response.status)) {
        continuePolling = false
        return
      }

      if (!response.ok) return

      const result = await response.json()
      this.element.textContent = result.label

      if (result.terminal) {
        continuePolling = false
        window.location.reload()
      }
    } catch (error) {
      if (error.name === "AbortError") continuePolling = false
    } finally {
      this.abortController = null

      if (continuePolling) this.scheduleRefresh()
    }
  }
}
