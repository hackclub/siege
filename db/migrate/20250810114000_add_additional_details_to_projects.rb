class AddAdditionalDetailsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :repo_url, :string
    add_column :projects, :demo_url, :string
  end
end
