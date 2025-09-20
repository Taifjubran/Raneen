class AddThumbnailUrlToPrograms < ActiveRecord::Migration[8.0]
  def change
    add_column :programs, :thumbnail_url, :string
  end
end
