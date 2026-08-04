class AddStatusToChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_enum :chat_message_status, %w[completed failed]

    add_column :chat_messages,
      :status,
      :enum,
      enum_type: :chat_message_status,
      null: false,
      default: "completed"

    add_column :chat_messages,
      :error_code,
      :string,
      limit: 100

    add_check_constraint :chat_messages,
      "(status = 'failed' AND error_code IS NOT NULL " \
        "AND char_length(btrim(error_code)) > 0) OR " \
        "(status = 'completed' AND error_code IS NULL)",
      name: "chat_messages_failure_metadata_consistent"

    add_check_constraint :chat_messages,
      "role = 'assistant' OR status = 'completed'",
      name: "chat_messages_user_status_completed"
  end
end
