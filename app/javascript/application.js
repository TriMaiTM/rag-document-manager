// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Global Turbo Submit handler to show circular spinner on active action buttons (excluding chat send button)
document.addEventListener("turbo:submit-start", (event) => {
  const submitBtn = event.target.querySelector('button[type="submit"], input[type="submit"]')
  if (submitBtn && !submitBtn.classList.contains("composer__submit") && !submitBtn.querySelector(".spinner-ring")) {
    submitBtn.dataset.originalHtml = submitBtn.innerHTML
    const spinner = document.createElement("span")
    spinner.className = "spinner-ring spinner-ring--sm"
    spinner.style.marginRight = "6px"
    submitBtn.prepend(spinner)
    submitBtn.disabled = true
  }
})

document.addEventListener("turbo:submit-end", (event) => {
  const submitBtn = event.target.querySelector('button[type="submit"], input[type="submit"]')
  if (submitBtn && submitBtn.dataset.originalHtml) {
    submitBtn.innerHTML = submitBtn.dataset.originalHtml
    submitBtn.disabled = false
  }
})
