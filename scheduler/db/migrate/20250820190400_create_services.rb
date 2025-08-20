class CreateServices < ActiveRecord::Migration[8.0]
  def change
    create_table :services do |t|
      t.string :name
      t.text :description
      t.integer :base_price_dollars
      t.integer :duration_minutes
      t.boolean :active

      t.timestamps
    end
  end
end
