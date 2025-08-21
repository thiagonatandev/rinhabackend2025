class AddTimestampsToPayments < ActiveRecord::Migration[7.0]
  def change
    add_timestamps :payments, null: true
  end
end
