class AddFraudFieldsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :fraud_status, :string, default: 'unchecked', null: false
    add_column :projects, :fraud_reasoning, :text

    add_index :projects, :fraud_status
  end
end
