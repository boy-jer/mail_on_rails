class CreateForwardings < ActiveRecord::Migration
  def change
    create_table :forwardings do |t|
      t.string :source
      t.text :destination

      t.timestamps
    end
  end
end
