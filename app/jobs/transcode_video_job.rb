class TranscodeVideoJob < ApplicationJob
  queue_as :default

  def perform(watch_party_id)
    watch_party = WatchParty.find(watch_party_id)
    
    return unless watch_party.video.attached?
    
    content_type = watch_party.video.content_type
    
    if needs_transcoding?(content_type)
      Rails.logger.info "Starting transcoding for WatchParty ##{watch_party.id}"
      
      watch_party.video.open do |file|
        output_path = Rails.root.join("tmp", "transcoded_#{watch_party.id}.webm")
        
        begin
          system(
            "ffmpeg",
            "-i", file.path,
            "-c:v", "libvpx-vp9",
            "-crf", "30",
            "-b:v", "0",
            "-c:a", "libopus",
            "-threads", "4",
            "-y",
            output_path.to_s
          )
          
          if $?.success? && File.exist?(output_path)
            watch_party.video.purge
            
            watch_party.video.attach(
              io: File.open(output_path),
              filename: "#{watch_party.title.parameterize}.webm",
              content_type: "video/webm"
            )
            
            watch_party.update!(processing_status: "ready")
            Rails.logger.info "Transcoding completed for WatchParty ##{watch_party.id}"
          else
            raise "FFmpeg transcoding failed"
          end
        rescue => e
          Rails.logger.error "Transcoding failed for WatchParty ##{watch_party.id}: #{e.message}"
          watch_party.update!(processing_status: "failed")
        ensure
          File.delete(output_path) if File.exist?(output_path)
        end
      end
    else
      watch_party.update!(processing_status: "ready")
    end
  end

  private

  def needs_transcoding?(content_type)
    !["video/mp4", "video/webm"].include?(content_type)
  end
end
