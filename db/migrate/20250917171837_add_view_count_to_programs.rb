class AddViewCountToPrograms < ActiveRecord::Migration[8.0]
  def change
    add_column :programs, :view_count, :integer
  end
end
