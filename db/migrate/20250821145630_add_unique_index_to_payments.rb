class AddUniqueIndexToPayments < ActiveRecord::Migration[8.0]
  def change
    add_index :payments, :correlation_id, unique: true
  end
end