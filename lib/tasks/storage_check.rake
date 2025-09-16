namespace :storage do
  desc "Check file integrity without cleanup"
  task check: :environment do
    puts "Checking storage file integrity..."

    missing_files = []
    total_blobs = 0

    ActiveStorage::Blob.includes(:attachments).find_each do |blob|
      total_blobs += 1
      unless blob.service.exist?(blob.key)
        missing_files << {
          key: blob.key,
          created_at: blob.created_at,
          filename: blob.filename,
          content_type: blob.content_type,
          attachments: blob.attachments.map { |a| "#{a.record_type}##{a.record_id} (#{a.name})" }
        }
      end
    end

    puts "Total blobs: #{total_blobs}"
    puts "Missing files: #{missing_files.count}"

    if missing_files.any?
      puts "\nMissing files details:"
      missing_files.each do |file|
        puts "  File: #{file[:filename]} (#{file[:key]})"
        puts "  Created: #{file[:created_at]}"
        puts "  Type: #{file[:content_type]}"
        puts "  Attached to: #{file[:attachments].join(', ')}"
        puts "  ---"
      end
    else
      puts "All files exist on disk ✓"
    end

    # Storage statistics
    storage_size = ActiveStorage::Blob.sum(:byte_size)
    puts "\nStorage Statistics:"
    puts "  Total blobs: #{total_blobs}"
    puts "  Total attachments: #{ActiveStorage::Attachment.count}"
    puts "  Storage size: #{(storage_size / 1024.0 / 1024.0).round(2)} MB"
  end
end
