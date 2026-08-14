import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "image", "initial", "filename"]

  update() {
    const file = this.inputTarget.files[0]
    if (!file) return

    if (this.hasFilenameTarget) {
      this.filenameTarget.textContent = file.name
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      if (this.hasImageTarget) {
        this.imageTarget.src = e.target.result
        this.imageTarget.style.display = "block"
      }
      if (this.hasInitialTarget) {
        this.initialTarget.style.display = "none"
      }
    }
    reader.readAsDataURL(file)
  }
}
