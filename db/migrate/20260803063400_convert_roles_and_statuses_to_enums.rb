# frozen_string_literal: true

class ConvertRolesAndStatusesToEnums < ActiveRecord::Migration[8.1]
  def up
    create_enum :membership_role, %w[owner admin member]
    create_enum :document_status, %w[pending processing completed failed]

    remove_check_constraint :memberships,
      name: "memberships_role_check"

    remove_check_constraint :documents,
      name: "documents_status_check"

    remove_index :memberships,
      name: "index_memberships_on_unique_workspace_owner"

    execute <<~SQL
      ALTER TABLE memberships
      ALTER COLUMN role TYPE membership_role
      USING role::membership_role
    SQL

    add_index :memberships,
      :workspace_id,
      unique: true,
      where: "role = 'owner'",
      name: "index_memberships_on_unique_workspace_owner"

    execute <<~SQL
      ALTER TABLE documents
      ALTER COLUMN status DROP DEFAULT
    SQL

    execute <<~SQL
      ALTER TABLE documents
      ALTER COLUMN status TYPE document_status
      USING status::document_status
    SQL

    execute <<~SQL
      ALTER TABLE documents
      ALTER COLUMN status SET DEFAULT 'pending'
    SQL
  end

  def down
    remove_index :memberships,
      name: "index_memberships_on_unique_workspace_owner"

    execute <<~SQL
      ALTER TABLE documents
      ALTER COLUMN status DROP DEFAULT
    SQL

    execute <<~SQL
      ALTER TABLE documents
      ALTER COLUMN status TYPE varchar
      USING status::text
    SQL

    execute <<~SQL
      ALTER TABLE documents
      ALTER COLUMN status SET DEFAULT 'pending'
    SQL

    execute <<~SQL
      ALTER TABLE memberships
      ALTER COLUMN role TYPE varchar
      USING role::text
    SQL

    add_index :memberships,
      :workspace_id,
      unique: true,
      where: "role = 'owner'",
      name: "index_memberships_on_unique_workspace_owner"

    add_check_constraint :memberships,
      "role IN ('owner', 'admin', 'member')",
      name: "memberships_role_check"

    add_check_constraint :documents,
      "status IN ('pending', 'processing', 'completed', 'failed')",
      name: "documents_status_check"

    drop_enum :document_status
    drop_enum :membership_role
  end
end
