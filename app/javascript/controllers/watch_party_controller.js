import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["video", "controls", "currentTime", "duration"]
  static values = {
    isAdmin: Boolean,
    watchPartyId: Number
  }

  connect() {
    this.subscription = consumer.subscriptions.create("WatchPartyChannel", {
      connected: this.cableConnected.bind(this),
      disconnected: this.cableDisconnected.bind(this),
      received: this.cableReceived.bind(this)
    })

    this.syncInProgress = false
    this.lastSyncTime = 0

    if (this.hasVideoTarget) {
      this.videoTarget.addEventListener('loadedmetadata', () => {
        if (this.hasDurationTarget) {
          this.durationTarget.textContent = this.formatTime(this.videoTarget.duration)
        }
      })

      this.videoTarget.addEventListener('timeupdate', () => {
        if (this.hasCurrentTimeTarget) {
          this.currentTimeTarget.textContent = this.formatTime(this.videoTarget.currentTime)
        }
      })

      if (!this.isAdminValue) {
        this.videoTarget.controls = false
      }

      if (this.isAdminValue) {
        this.videoTarget.addEventListener('play', () => this.broadcastState())
        this.videoTarget.addEventListener('pause', () => this.broadcastState())
        this.videoTarget.addEventListener('seeked', () => this.broadcastState())
      }
    }
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  cableConnected() {
    console.log("Connected to WatchPartyChannel")
  }

  cableDisconnected() {
    console.log("Disconnected from WatchPartyChannel")
  }

  cableReceived(data) {
    if (this.isAdminValue) return

    if (this.syncInProgress) return

    const now = Date.now() / 1000
    const expectedTime = data.current_time + (now - data.timestamp)
    const drift = Math.abs(this.videoTarget.currentTime - expectedTime)

    this.syncInProgress = true

    if (drift > 1.0) {
      this.videoTarget.currentTime = expectedTime
    }

    if (data.is_playing && this.videoTarget.paused) {
      this.videoTarget.play().catch(e => console.error("Play failed:", e))
    } else if (!data.is_playing && !this.videoTarget.paused) {
      this.videoTarget.pause()
    }

    setTimeout(() => {
      this.syncInProgress = false
    }, 100)
  }

  broadcastState() {
    if (!this.isAdminValue) return

    const now = Date.now()
    if (now - this.lastSyncTime < 100) return

    this.lastSyncTime = now

    fetch(`/watch/${this.watchPartyIdValue}/update_state`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        current_time: this.videoTarget.currentTime,
        is_playing: !this.videoTarget.paused
      })
    })
  }

  formatTime(seconds) {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const secs = Math.floor(seconds % 60)

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`
  }
}
