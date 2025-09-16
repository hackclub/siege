class AddAuditLogsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :audit_logs, :json, default: []
  end
end
