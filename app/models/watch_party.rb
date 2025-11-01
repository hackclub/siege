class WatchParty < ApplicationRecord
  has_one_attached :video

  validates :title, presence: true
  validates :current_time, numericality: { greater_than_or_equal_to: 0 }
  validate :video_must_be_video

  after_initialize :set_defaults, if: :new_record?

  def broadcast_state
    ActionCable.server.broadcast(
      "watch_party_channel",
      {
        current_time: current_time,
        is_playing: is_playing,
        timestamp: Time.now.to_f
      }
    )
  end

  private

  def set_defaults
    self.current_time ||= 0.0
    self.is_playing ||= false
    self.last_updated_at ||= Time.current
  end

  def video_must_be_video
    return unless video.attached?

    unless video.content_type.in?(%w[video/mp4 video/quicktime video/x-msvideo video/webm])
      errors.add(:video, "must be a video file (MP4, MOV, AVI, or WebM)")
    end
  end
end
