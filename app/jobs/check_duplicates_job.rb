class CheckDuplicatesJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[CheckDuplicatesJob] Starting job execution"
    
    # Check if required environment variable is present
    unless ENV["UNIFIED_DB_INTEGRATION_AIRTABLE_KEY"].present?
      Rails.logger.error "[CheckDuplicatesJob] Missing UNIFIED_DB_INTEGRATION_AIRTABLE_KEY environment variable"
      return
    end
    
    begin
      records_to_check = source_table.all(
        max_records: 10,
        filter: "BLANK() = {Duplicate?}",
        sort: { "Created at": "asc" }
      )
    rescue => e
      Rails.logger.error "[CheckDuplicatesJob] Failed to fetch records from Airtable: #{e.message}"
      return
    end

    if records_to_check.empty?
      Rails.logger.info "[CheckDuplicatesJob] No records to check"
      return
    end

    Rails.logger.info "[CheckDuplicatesJob] Found #{records_to_check.count} records to check for duplicates"

    records_to_update = []

    records_to_check.each do |record|
      code_url = record.fields["Code URL"]

      unless code_url.present?
        Rails.logger.info "[CheckDuplicatesJob] Skipping record #{record.id} - no Code URL"
        next
      end

      duplicate_record = find_duplicate_in_unified_db(code_url)

      if duplicate_record
        Rails.logger.info "[CheckDuplicatesJob] Found duplicate for #{code_url}: #{duplicate_record.id}"
        record["Duplicate?"] = duplicate_record.id
      else
        Rails.logger.info "[CheckDuplicatesJob] No duplicate found for #{code_url}"
        record["Duplicate?"] = "N/A"
      end

      records_to_update << record
    end

    if records_to_update.any?
      begin
        source_table.batch_update(records_to_update)
        Rails.logger.info "[CheckDuplicatesJob] Successfully updated #{records_to_update.count} records with duplicate status"
      rescue => e
        Rails.logger.error "[CheckDuplicatesJob] Failed to update records: #{e.message}"
        return
      end
    end
    
    Rails.logger.info "[CheckDuplicatesJob] Job execution completed"
  rescue => e
    Rails.logger.error "[CheckDuplicatesJob] Job failed with error: #{e.message}"
    Rails.logger.error "[CheckDuplicatesJob] Backtrace: #{e.backtrace.join("\n")}"
    raise e
  end

  private

  def find_duplicate_in_unified_db(code_url)
    unified_db_table.all(
      filter: "AND({Code URL} = '#{code_url}', NOT({YSWS} = 'Siege'))"
    ).first
  end

  def source_table
    @source_table ||= Norairrecord.table(
      ENV["UNIFIED_DB_INTEGRATION_AIRTABLE_KEY"],
      "appsTAwyYsRzZ0mCo",
      "tblBQ2aKCQanXJSaa"
    )
  end

  def unified_db_table
    @unified_db_table ||= Norairrecord.table(
      ENV["UNIFIED_DB_INTEGRATION_AIRTABLE_KEY"],
      "app3A5kJwYqxMLOgh",
      "Approved Projects"
    )
  end
end
