class AddTranscodingProgressToPrograms < ActiveRecord::Migration[8.0]
  def change
    add_column :programs, :transcoding_progress, :integer
  end
end
