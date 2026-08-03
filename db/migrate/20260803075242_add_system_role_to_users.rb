class AddSystemRoleToUsers < ActiveRecord::Migration[8.1]
  def up
    create_enum :user_system_role, %w[user system_admin]

    add_column :users,
               :system_role,
               :enum,
               enum_type: :user_system_role,
               default: "user",
               null: false
  end

  def down
    remove_column :users, :system_role
    drop_enum :user_system_role
  end
end
