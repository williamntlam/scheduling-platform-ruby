class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.string :name
      t.string :city
      t.string :country
      t.string :postal_code

      t.timestamps
    end
  end
end
