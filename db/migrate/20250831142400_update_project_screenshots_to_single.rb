class UpdateProjectScreenshotsToSingle < ActiveRecord::Migration[8.0]
  def up
    # This migration handles the transition from has_many_attached :screenshots to has_one_attached :screenshot
    # ActiveStorage handles the attachment changes automatically, so we don't need to modify the database schema
    # The change is purely in the model association
  end

  def down
    # No rollback needed as this is just a model association change
  end
end
