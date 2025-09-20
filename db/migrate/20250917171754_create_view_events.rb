class CreateViewEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :view_events do |t|
      t.references :program, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :session_id
      t.string :event_type
      t.integer :duration_seconds
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
