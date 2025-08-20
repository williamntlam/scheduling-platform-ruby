class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :booking, null: false, foreign_key: true
      t.string :provider
      t.string :status
      t.integer :amount_cents
      t.string :external_ref

      t.timestamps
    end
  end
end
