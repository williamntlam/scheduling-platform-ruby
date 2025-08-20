class CreateScheduleSlots < ActiveRecord::Migration[8.0]
  def change
    create_table :schedule_slots do |t|
      t.references :service, null: false, foreign_key: true
      t.references :provider, User: true, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :capacity
      t.boolean :active

      t.timestamps
    end
  end
end
