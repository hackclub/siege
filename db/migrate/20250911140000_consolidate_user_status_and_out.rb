class ConsolidateUserStatusAndOut < ActiveRecord::Migration[8.0]
  def up
    # Update users based on their current status and out boolean
    # Migration logic:
    # - out=true -> status='banned'
    # - status='working' and out=false -> status='new' (existing users go through welcome)
    # - status='completed' and out=false -> status='new' (existing users go through welcome)
    # - status='out' and out=false -> status='out' (keep existing logic)
    # New users will start with status='new'

    # First, update users who are marked as out=true to banned
    User.where(out: true).update_all(status: 'banned')

    # Users with status='working' should become 'new' to go through welcome flow
    User.where(status: 'working', out: false).update_all(status: 'new')

    # Users with status='completed' should also become 'new'
    User.where(status: 'completed', out: false).update_all(status: 'new')

    # Users with status='out' and out=false should keep status='out'
    # (this handles existing users who were manually set to 'out' status)

    # Remove the out column since it's now consolidated into status
    remove_column :users, :out

    # Update the status validation to include new values
    # This will be handled in the model, but we ensure the column allows the new values
  end

  def down
    # Add back the out column
    add_column :users, :out, :boolean, default: false, null: false

    # Restore the out boolean based on status
    User.where(status: 'banned').update_all(out: true, status: 'working')
    User.where(status: 'new').update_all(status: 'working')
    # status='out' users keep their status but out remains false
    # status='working' users keep their status and out remains false
  end
end
