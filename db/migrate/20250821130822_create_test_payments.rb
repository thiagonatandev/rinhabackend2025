class CreateTestPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :test_payments do |t|
      t.string :name

      t.timestamps
    end
  end
end
