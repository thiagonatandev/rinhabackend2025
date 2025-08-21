class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.uuid :correlation_id, null: false, index: { unique: true }
      t.decimal :amount, null: false, precision: 12, scale: 2
      t.timestamps
    end
  end
end
