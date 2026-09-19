import { Controller } from "@hotwired/stimulus"

// Autoscrolls the notebook to the currently running cell whenever a Turbo Stream swap lands.
export default class extends Controller {
  connect() {
    this.onStreamRender = this.onStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.onStreamRender)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.onStreamRender)
  }

  onStreamRender() {
    requestAnimationFrame(() => requestAnimationFrame(() => this.scrollToRunning()))
  }

  scrollToRunning() {
    const running = this.element.querySelector("[data-running='true']")
    if (running) running.scrollIntoView({ behavior: "smooth", block: "center" })
  }
}
