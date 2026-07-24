class CreateMemberships < ActiveRecord::Migration[8.1]
  def up
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end

    add_index :memberships,
      [ :workspace_id, :user_id ],
      unique: true

    add_index :memberships,
      :workspace_id,
      unique: true,
      where: "role = 'owner'",
      name: "index_memberships_on_unique_workspace_owner"

    add_check_constraint :memberships,
      "role IN ('owner', 'admin', 'member')",
      name: "memberships_role_check"

    backfill_existing_workspaces
  end

  def down
    drop_table :memberships
  end

  private

  def backfill_existing_workspaces
    execute <<~SQL
      INSERT INTO memberships (
        user_id,
        workspace_id,
        role,
        created_at,
        updated_at
      )
      SELECT
        (
          SELECT id
          FROM users
          ORDER BY created_at ASC, id ASC
          LIMIT 1
        ),
        workspaces.id,
        'owner',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM workspaces
      WHERE EXISTS (SELECT 1 FROM users)
    SQL

    orphan_count = select_value(<<~SQL).to_i
      SELECT COUNT(*)
      FROM workspaces
      LEFT JOIN memberships
        ON memberships.workspace_id = workspaces.id
      WHERE memberships.id IS NULL
    SQL

    return if orphan_count.zero?

    raise ActiveRecord::MigrationError,
      "Cannot assign existing workspaces because no user exists"
  end
end
