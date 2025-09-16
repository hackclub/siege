namespace :storage do
  desc "Clean up orphaned blobs and verify file integrity"
  task maintenance: :environment do
    puts "Starting storage maintenance..."

    # Remove orphaned blobs (blobs not attached to any record and older than 1 day)
    puts "Checking for orphaned blobs..."
    orphaned_count = 0
    old_orphaned_blobs = ActiveStorage::Blob.unattached.where("created_at < ?", 1.day.ago)

    puts "Found #{old_orphaned_blobs.count} potentially orphaned blobs (older than 1 day)"

    # Only remove if explicitly requested
    if ENV["REMOVE_ORPHANED"] == "true"
      old_orphaned_blobs.find_each do |blob|
        Rails.logger.info "Purging orphaned blob: #{blob.key} (created: #{blob.created_at})"
        blob.purge
        orphaned_count += 1
      end
      puts "Removed #{orphaned_count} orphaned blobs"
    else
      puts "Found #{old_orphaned_blobs.count} orphaned blobs. Run with REMOVE_ORPHANED=true to remove them."
    end

    # Verify file integrity for attached blobs
    puts "Verifying file integrity..."
    missing_files = []
    corrupted_attachments = []

    ActiveStorage::Blob.with_attached_attachments.find_each do |blob|
      unless blob.service.exist?(blob.key)
        missing_files << blob.key
        Rails.logger.error "Missing file for blob: #{blob.key}"

        # Find which records are affected
        blob.attachments.each do |attachment|
          corrupted_attachments << {
            record_type: attachment.record_type,
            record_id: attachment.record_id,
            name: attachment.name,
            blob_key: blob.key
          }
        end
      end
    end

    if missing_files.any?
      puts "WARNING: #{missing_files.count} files are missing from storage:"
      corrupted_attachments.each do |attachment|
        puts "  - #{attachment[:record_type]}##{attachment[:record_id]} (#{attachment[:name]}): #{attachment[:blob_key]}"
      end

      # Optionally remove corrupted attachment records
      if ENV["REMOVE_CORRUPTED"] == "true"
        puts "Removing corrupted attachment records..."
        ActiveStorage::Blob.where(key: missing_files).destroy_all
        puts "Removed #{missing_files.count} corrupted blob records"
      else
        puts "Run with REMOVE_CORRUPTED=true to automatically remove corrupted records"
      end
    else
      puts "All files verified successfully"
    end

    # Report storage statistics
    total_blobs = ActiveStorage::Blob.count
    total_attachments = ActiveStorage::Attachment.count
    storage_size = ActiveStorage::Blob.sum(:byte_size)

    puts "\nStorage Statistics:"
    puts "  Total blobs: #{total_blobs}"
    puts "  Total attachments: #{total_attachments}"
    puts "  Storage size: #{(storage_size / 1024.0 / 1024.0).round(2)} MB"

    puts "Storage maintenance completed!"
  end

  desc "List all screenshot attachments and their status"
  task audit_screenshots: :environment do
    puts "Auditing project screenshots..."

    projects_with_screenshots = Project.joins(:screenshot_attachment).includes(screenshot_attachment: :blob)
    projects_without_screenshots = Project.left_joins(:screenshot_attachment).where(active_storage_attachments: { id: nil })

    puts "\nProjects with screenshots: #{projects_with_screenshots.count}"
    projects_with_screenshots.each do |project|
      blob = project.screenshot.blob
      file_exists = blob.service.exist?(blob.key)
      status = file_exists ? "✓ OK" : "✗ MISSING"
      puts "  Project #{project.id} (#{project.name}): #{status} - #{blob.key}"
    end

    puts "\nProjects without screenshots: #{projects_without_screenshots.count}"

    puts "\nScreenshot audit completed!"
  end

  desc "Backup storage directory"
  task backup: :environment do
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    backup_dir = Rails.root.join("tmp", "storage_backups", timestamp)
    storage_dir = Rails.root.join("storage")

    puts "Creating storage backup..."
    puts "From: #{storage_dir}"
    puts "To: #{backup_dir}"

    FileUtils.mkdir_p(backup_dir)
    FileUtils.cp_r(storage_dir, backup_dir)

    # Create manifest file
    manifest = {
      created_at: Time.current,
      total_files: Dir.glob("#{storage_dir}/**/*").select { |f| File.file?(f) }.count,
      total_size: `du -sb #{storage_dir}`.split("\t").first.to_i,
      rails_env: Rails.env
    }

    File.write(backup_dir.join("manifest.json"), manifest.to_json)

    puts "Backup created successfully!"
    puts "Backup location: #{backup_dir}"
    puts "Total files: #{manifest[:total_files]}"
    puts "Total size: #{(manifest[:total_size] / 1024.0 / 1024.0).round(2)} MB"

    # Clean up old backups (keep last 7 days)
    old_backups = Dir.glob(Rails.root.join("tmp", "storage_backups", "*"))
                    .select { |d| File.directory?(d) && File.mtime(d) < 7.days.ago }

    old_backups.each do |backup|
      puts "Removing old backup: #{backup}"
      FileUtils.rm_rf(backup)
    end
  end
end
