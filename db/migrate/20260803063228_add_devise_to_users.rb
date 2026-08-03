# frozen_string_literal: true

class AddDeviseToUsers < ActiveRecord::Migration[8.1]
  def up
    rename_column :users,
      :email_address,
      :email

    rename_column :users,
      :password_digest,
      :encrypted_password

    change_column_default :users,
      :email,
      from: nil,
      to: ""

    change_column_default :users,
      :encrypted_password,
      from: nil,
      to: ""

    rename_email_index

    change_table :users do |t|
      # Recoverable
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      # Rememberable
      t.datetime :remember_created_at
    end

    add_index :users,
      :reset_password_token,
      unique: true
  end

  def down
    remove_index :users,
      :reset_password_token

    remove_column :users,
      :remember_created_at

    remove_column :users,
      :reset_password_sent_at

    remove_column :users,
      :reset_password_token

    change_column_default :users,
      :email,
      from: "",
      to: nil

    change_column_default :users,
      :encrypted_password,
      from: "",
      to: nil

    restore_email_index

    rename_column :users,
      :encrypted_password,
      :password_digest

    rename_column :users,
      :email,
      :email_address
  end

  private

  def rename_email_index
    old_name = "index_users_on_email_address"
    new_name = "index_users_on_email"

    return unless index_name_exists?(:users, old_name)
    return if index_name_exists?(:users, new_name)

    rename_index :users, old_name, new_name
  end

  def restore_email_index
    old_name = "index_users_on_email"
    new_name = "index_users_on_email_address"

    return unless index_name_exists?(:users, old_name)
    return if index_name_exists?(:users, new_name)

    rename_index :users, old_name, new_name
  end
end
