# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_17_193216) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "uuid-ossp"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "program_kind", ["podcast", "documentary"]
  create_enum "program_status", ["draft", "processing", "ready", "failed"]

  create_table "programs", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.enum "kind", default: "podcast", enum_type: "program_kind"
    t.string "language", default: "en"
    t.string "category"
    t.integer "duration_seconds"
    t.datetime "published_at"
    t.enum "status", default: "draft", enum_type: "program_status"
    t.string "external_url"
    t.string "tags", default: [], array: true
    t.string "source_s3_key"
    t.string "stream_path"
    t.string "poster_url"
    t.string "mediaconvert_job_id"
    t.bigint "filesize_bytes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "transcoding_progress"
    t.string "thumbnail_url"
    t.integer "view_count"
    t.string "preview_video_url"
    t.string "sprite_sheet_url"
    t.index ["category"], name: "index_programs_on_category"
    t.index ["description"], name: "index_programs_on_description"
    t.index ["kind"], name: "index_programs_on_kind"
    t.index ["language"], name: "index_programs_on_language"
    t.index ["published_at"], name: "index_programs_on_published_at"
    t.index ["status"], name: "index_programs_on_status"
    t.index ["tags"], name: "index_programs_on_tags", using: :gin
    t.index ["title"], name: "index_programs_on_title"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "view_events", force: :cascade do |t|
    t.bigint "program_id", null: false
    t.bigint "user_id", null: false
    t.string "session_id"
    t.string "event_type"
    t.integer "duration_seconds"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["program_id"], name: "index_view_events_on_program_id"
    t.index ["user_id"], name: "index_view_events_on_user_id"
  end

  add_foreign_key "view_events", "programs"
  add_foreign_key "view_events", "users"
end
