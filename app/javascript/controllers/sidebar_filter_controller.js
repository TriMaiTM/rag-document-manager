import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item"]

  filter() {
    const query = this.inputTarget.value.trim().toLocaleLowerCase("vi")

    this.itemTargets.forEach((item) => {
      item.hidden = query.length > 0 && !item.dataset.filterValue.includes(query)
    })
  }
}
