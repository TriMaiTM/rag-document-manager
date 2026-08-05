class AllowPendingChatMessageStatus < ActiveRecord::Migration[8.1]
  CONSTRAINT_NAME = "chat_messages_failure_metadata_consistent"

  def up
    remove_check_constraint :chat_messages, name: CONSTRAINT_NAME

    add_check_constraint :chat_messages,
      "(status = 'failed' AND error_code IS NOT NULL " \
        "AND char_length(btrim(error_code)) > 0) OR " \
        "(status IN ('pending', 'completed') AND error_code IS NULL)",
      name: CONSTRAINT_NAME
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Pending messages may exist after this migration"
  end
end
