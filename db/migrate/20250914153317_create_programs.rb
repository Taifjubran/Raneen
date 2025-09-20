class CreatePrograms < ActiveRecord::Migration[8.0]
  def up
    create_enum :program_kind, ["podcast", "documentary"]
    create_enum :program_status, ["draft", "processing", "ready", "failed"]

    create_table :programs do |t|
      t.string :title, null: false
      t.text :description
      t.enum :kind, enum_type: :program_kind, default: "podcast"
      t.string :language, default: "en"
      t.string :category
      t.integer :duration_seconds
      t.datetime :published_at
      t.enum :status, enum_type: :program_status, default: "draft"
      t.string :external_url
      t.string :tags, array: true, default: []
      t.string :source_s3_key
      t.string :stream_path
      t.string :poster_url
      t.string :mediaconvert_job_id
      t.bigint :filesize_bytes
      
      t.timestamps
    end

    add_index :programs, :title
    add_index :programs, :description
    add_index :programs, :kind
    add_index :programs, :language
    add_index :programs, :category
    add_index :programs, :published_at
    add_index :programs, :status
    add_index :programs, :tags, using: :gin
  end

  def down
    drop_table :programs
    drop_enum :program_kind
    drop_enum :program_status
  end
end
