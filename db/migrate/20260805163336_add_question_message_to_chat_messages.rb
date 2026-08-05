class AddQuestionMessageToChatMessages < ActiveRecord::Migration[8.1]
  def change
    add_reference :chat_messages,
      :question_message,
      null: true,
      index: false,
      foreign_key: {
        to_table: :chat_messages,
        on_delete: :cascade
      }

    add_index :chat_messages,
      :question_message_id,
      unique: true,
      where: "question_message_id IS NOT NULL",
      name: "index_chat_messages_unique_answer"
  end
end
