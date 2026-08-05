class AddPendingStatusToChatMessages < ActiveRecord::Migration[8.1]
  def up
    add_enum_value :chat_message_status, "pending", before: "completed"
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "PostgreSQL enum values cannot be removed safely"
  end
end
