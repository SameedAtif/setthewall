import { Controller } from "@hotwired/stimulus"

// Polls the "surveys" turbo frame and chimes when a running survey finishes, so a long-running
// ideation job can be left alone and its completion is announced. The title is flashed too, so
// the completion is visible even when the tab is in the background.
export default class extends Controller {
  static values = { pollInterval: { type: Number, default: 3000 } }

  connect() {
    this.wasRunning = false
    this.refreshing = false
    this.audioCtx = null
    this.unlockAudio()

    this.timer = setInterval(() => this.refresh(), this.pollIntervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async refresh() {
    if (this.refreshing) return
    this.refreshing = true
    try {
      const frame = document.getElementById("surveys")
      if (!frame) return

      await frame.reload()

      const running = this.runningIds()
      if (this.wasRunning && running.length === 0) this.announceCompletion()

      this.wasRunning = running.length > 0
    } finally {
      this.refreshing = false
    }
  }

  runningIds() {
    return [...this.element.querySelectorAll("[data-status='running']")]
      .map((el) => el.dataset.surveyId)
  }

  announceCompletion() {
    this.playChime()
    this.flashTitle()
  }

  flashTitle() {
    const base = document.title
    document.title = "✓ Done — " + base
    setTimeout(() => { document.title = base }, 8000)
  }

  unlockAudio() {
    const unlock = () => {
      if (!this.audioCtx) {
        const AudioContext = window.AudioContext || window.webkitAudioContext
        if (AudioContext) this.audioCtx = new AudioContext()
      }
      this.audioCtx?.resume()
      document.removeEventListener("pointerdown", unlock)
      document.removeEventListener("keydown", unlock)
    }
    document.addEventListener("pointerdown", unlock)
    document.addEventListener("keydown", unlock)
  }

  playChime() {
    if (!this.audioCtx) return

    const ctx = this.audioCtx
    const notes = [
      { freq: 880.0, at: 0.0 },
      { freq: 1174.66, at: 0.18 },
    ]

    notes.forEach(({ freq, at }) => {
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.type = "sine"
      osc.frequency.value = freq

      gain.gain.setValueAtTime(0.0001, ctx.currentTime + at)
      gain.gain.exponentialRampToValueAtTime(0.3, ctx.currentTime + at + 0.02)
      gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + at + 0.45)

      osc.connect(gain).connect(ctx.destination)
      osc.start(ctx.currentTime + at)
      osc.stop(ctx.currentTime + at + 0.5)
    })
  }
}
