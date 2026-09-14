import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "fileList", "titleContainer", "titleInput", "submitBtn"]

  filesChanged() {
    const files = this.inputTarget.files
    if (!files || files.length === 0) {
      if (this.hasFileListTarget) {
        this.fileListTarget.style.display = "none"
        this.fileListTarget.innerHTML = ""
      }
      if (this.hasSubmitBtnTarget) {
        this.submitBtnTarget.value = "Tải lên và xử lý"
      }
      if (this.hasTitleContainerTarget) {
        this.titleContainerTarget.style.display = "block"
      }
      return
    }

    if (files.length === 1) {
      const file = files[0]
      if (this.hasTitleInputTarget && !this.titleInputTarget.value.trim()) {
        const cleanName = file.name.replace(/\.[^/.]+$/, "").replace(/[_-]+/g, " ").trim()
        this.titleInputTarget.value = cleanName
      }
      if (this.hasTitleContainerTarget) {
        this.titleContainerTarget.style.display = "block"
      }
      if (this.hasSubmitBtnTarget) {
        this.submitBtnTarget.value = "Tải lên và xử lý"
      }
      if (this.hasFileListTarget) {
        this.fileListTarget.style.display = "block"
        this.fileListTarget.innerHTML = `
          <div class="selected-files-box">
            <div class="selected-file-row">
              <span class="file-name">📄 ${file.name}</span>
              <span class="file-size">${this.formatSize(file.size)}</span>
            </div>
          </div>
        `
      }
    } else {
      if (this.hasTitleContainerTarget) {
        this.titleContainerTarget.style.display = "none"
      }
      if (this.hasSubmitBtnTarget) {
        this.submitBtnTarget.value = `Tải lên (${files.length} tệp) và xử lý`
      }
      if (this.hasFileListTarget) {
        this.fileListTarget.style.display = "block"
        let itemsHtml = ""
        for (let i = 0; i < files.length; i++) {
          const f = files[i]
          itemsHtml += `
            <div class="selected-file-row">
              <span class="file-name">📄 ${f.name}</span>
              <span class="file-size">${this.formatSize(f.size)}</span>
            </div>
          `
        }
        this.fileListTarget.innerHTML = `
          <div class="selected-files-box">
            <div class="selected-files-summary">Đã chọn <strong>${files.length}</strong> tệp PDF (Tên tài liệu sẽ tạo tự động):</div>
            <div class="selected-files-scroll">${itemsHtml}</div>
          </div>
        `
      }
    }
  }

  formatSize(bytes) {
    if (bytes < 1024) return bytes + " B"
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
    return (bytes / (1024 * 1024)).toFixed(1) + " MB"
  }
}
