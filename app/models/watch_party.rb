class WatchParty < ApplicationRecord
  has_one_attached :video

  validates :title, presence: true
  validates :current_time, numericality: { greater_than_or_equal_to: 0 }
  validate :video_must_be_video

  after_initialize :set_defaults, if: :new_record?
  after_commit :enqueue_transcoding, on: :create

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

  def ready?
    processing_status == "ready"
  end

  def processing?
    processing_status == "pending" || processing_status == "processing"
  end

  def failed?
    processing_status == "failed"
  end

  private

  def set_defaults
    self.current_time ||= 0.0
    self.is_playing ||= false
    self.last_updated_at ||= Time.current
    self.processing_status ||= "pending"
  end

  def video_must_be_video
    return unless video.attached?

    allowed_types = %w[
      video/mp4 
      video/quicktime 
      video/x-msvideo 
      video/webm
      video/x-matroska
      video/avi
    ]
    
    unless video.content_type.in?(allowed_types)
      errors.add(:video, "must be a video file (MP4, MOV, AVI, MKV, or WebM)")
    end
  end

  def enqueue_transcoding
    TranscodeVideoJob.perform_later(id) if video.attached?
  end
end
