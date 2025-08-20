class CreateBookings < ActiveRecord::Migration[8.0]
  def change
    create_table :bookings do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :schedule_slot, null: false, foreign_key: true
      t.string :state
      t.integer :price_cents
      t.string :currency
      t.integer :cancellation_fee_dollars
      t.string :canceled_reason

      t.timestamps
    end
  end
end
