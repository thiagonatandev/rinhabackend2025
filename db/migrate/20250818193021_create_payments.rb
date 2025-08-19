class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.uuid :correlation_id
      t.decimal :amount

    end
  end
end
