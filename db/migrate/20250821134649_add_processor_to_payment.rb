class AddProcessorToPayment < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :processor, :string
  end
end
