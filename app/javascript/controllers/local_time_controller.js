import { Controller } from "@hotwired/stimulus"

// Renders a server-side UTC timestamp (in the element's `datetime` attribute) in the viewer's
// local timezone. Attached to each <time> so Turbo Stream-appended log lines are converted too.
export default class extends Controller {
  connect() {
    const iso = this.element.getAttribute("datetime")
    if (!iso) return

    const date = new Date(iso)
    if (Number.isNaN(date.getTime())) return

    this.element.textContent = date.toLocaleString(undefined, {
      year: "numeric",
      month: "short",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false
    })
  }
}
