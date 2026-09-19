import { Controller } from "@hotwired/stimulus"

// Full-screen image preview. Any image rendered with `data-lightbox-image` opens in a modal;
// clicking the backdrop or pressing Escape closes it, and prev/next (buttons or ArrowLeft/Right)
// move between the images inside the same `data-lightbox-scope` (one cell's output).
export default class extends Controller {
  static targets = ["modal", "image", "prev", "next", "counter"]

  connect() {
    this.images = []
    this.index = 0
  }

  open(event) {
    const thumb = event.target.closest("[data-lightbox-image]")
    if (!thumb) return

    const scope = thumb.closest("[data-lightbox-scope]") || this.element
    this.images = Array.from(scope.querySelectorAll("[data-lightbox-image]"))
    this.index = this.images.indexOf(thumb)
    if (this.index < 0) return

    this.render()
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    if (!this.hasModalTarget || this.modalTarget.classList.contains("hidden")) return

    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
    document.body.classList.remove("overflow-hidden")
  }

  previous(event) {
    event?.preventDefault()
    this.step(-1)
  }

  next(event) {
    event?.preventDefault()
    this.step(1)
  }

  step(delta) {
    if (this.images.length < 2) return

    this.index = (this.index + delta + this.images.length) % this.images.length
    this.render()
  }

  // Clicks on the backdrop (not the figure/buttons) close the modal.
  backdrop(event) {
    if (event.target === this.modalTarget) this.close()
  }

  keydown(event) {
    if (!this.hasModalTarget || this.modalTarget.classList.contains("hidden")) return

    if (event.key === "Escape") this.close()
    if (event.key === "ArrowLeft") this.step(-1)
    if (event.key === "ArrowRight") this.step(1)
  }

  render() {
    const current = this.images[this.index]
    if (!current) return

    this.imageTarget.src = current.dataset.lightboxSrc || current.currentSrc || current.src
    this.imageTarget.alt = current.alt || ""

    const multiple = this.images.length > 1
    this.prevTarget.classList.toggle("hidden", !multiple)
    this.nextTarget.classList.toggle("hidden", !multiple)
    this.counterTarget.textContent = multiple ? `${this.index + 1} / ${this.images.length}` : ""
  }
}
