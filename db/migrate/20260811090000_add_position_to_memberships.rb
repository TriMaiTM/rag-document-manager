class AddPositionToMemberships < ActiveRecord::Migration[8.1]
  def up
    add_column :memberships, :position, :integer, default: 0, null: false

    execute <<~SQL.squish
      WITH ordered_memberships AS (
        SELECT id,
          ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY created_at, id
          ) - 1 AS sidebar_position
        FROM memberships
      )
      UPDATE memberships
      SET position = ordered_memberships.sidebar_position
      FROM ordered_memberships
      WHERE memberships.id = ordered_memberships.id
    SQL

    add_index :memberships, [ :user_id, :position ]
    add_check_constraint :memberships,
      "position >= 0",
      name: "memberships_position_non_negative"
  end

  def down
    remove_check_constraint :memberships,
      name: "memberships_position_non_negative"
    remove_index :memberships, [ :user_id, :position ]
    remove_column :memberships, :position
  end
end
