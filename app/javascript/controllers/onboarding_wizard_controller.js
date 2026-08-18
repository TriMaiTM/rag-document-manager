import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "step1", "step2",
    "step1Indicator", "step2Indicator",
    "nameInput"
  ]

  nextStep(event) {
    if (event) event.preventDefault()

    this.step1Target.classList.add("is-hidden")
    this.step2Target.classList.remove("is-hidden")

    this.step1IndicatorTarget.classList.remove("is-active")
    this.step1IndicatorTarget.classList.add("is-completed")

    this.step2IndicatorTarget.classList.add("is-active")
  }

  prevStep(event) {
    if (event) event.preventDefault()

    this.step2Target.classList.add("is-hidden")
    this.step1Target.classList.remove("is-hidden")

    this.step2IndicatorTarget.classList.remove("is-active")

    this.step1IndicatorTarget.classList.remove("is-completed")
    this.step1IndicatorTarget.classList.add("is-active")
  }
}
