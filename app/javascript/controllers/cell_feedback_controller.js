import { Controller } from "@hotwired/stimulus"

// Gives immediate feedback while the reviewer's prose is being interpreted.
export default class extends Controller {
  static targets = ["submit"]

  submit() {
    if (!this.hasSubmitTarget) return

    this.submitTarget.dataset.label = this.submitTarget.value
    this.submitTarget.value = "Interpreting…"
    this.submitTarget.disabled = true
  }

  reset() {
    if (!this.hasSubmitTarget || !this.submitTarget.dataset.label) return

    this.submitTarget.value = this.submitTarget.dataset.label
    this.submitTarget.disabled = false
  }
}
