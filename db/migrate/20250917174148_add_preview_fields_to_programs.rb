class AddPreviewFieldsToPrograms < ActiveRecord::Migration[8.0]
  def change
    add_column :programs, :preview_video_url, :string
    add_column :programs, :sprite_sheet_url, :string
  end
end
