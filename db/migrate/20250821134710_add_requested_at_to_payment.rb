class AddRequestedAtToPayment < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :requested_at, :datetime
  end
end
