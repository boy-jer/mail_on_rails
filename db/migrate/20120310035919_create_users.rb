class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :username
      t.string :email
      t.string :password
      t.integer :domain_id
      t.string :backup_email

      t.timestamps
    end
  end
end
