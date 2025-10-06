class CheckDuplicatesJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[CheckDuplicatesJob] Starting job execution"
    
    records_to_check = source_table.all(
      max_records: 10,
      filter: "BLANK() = {Duplicate?}",
      sort: { "Created at": "asc" }
    )

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
      source_table.batch_update(records_to_update)
      Rails.logger.info "[CheckDuplicatesJob] Successfully updated #{records_to_update.count} records with duplicate status"
    end
    
    Rails.logger.info "[CheckDuplicatesJob] Job execution completed"
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
