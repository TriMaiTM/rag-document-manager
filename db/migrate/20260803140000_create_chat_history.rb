class CreateChatHistory < ActiveRecord::Migration[8.1]
  def change
    create_enum :chat_message_role, %w[user assistant]

    create_table :chat_sessions do |t|
      t.references :workspace,
        null: false,
        foreign_key: { on_delete: :cascade }

      t.references :user,
        null: false,
        foreign_key: true

      t.string :title, null: false

      t.timestamps
    end

    add_index :chat_sessions,
      [ :workspace_id, :user_id, :updated_at ],
      name: "index_chat_sessions_on_workspace_user_updated_at"

    add_check_constraint :chat_sessions,
      "char_length(btrim(title)) > 0",
      name: "chat_sessions_title_not_blank"

    create_table :chat_messages do |t|
      t.references :chat_session,
        null: false,
        foreign_key: { on_delete: :cascade }

      t.enum :role,
        enum_type: :chat_message_role,
        null: false

      t.text :content, null: false
      t.string :model

      t.integer :prompt_tokens, null: false, default: 0
      t.integer :candidate_tokens, null: false, default: 0
      t.integer :total_tokens, null: false, default: 0

      t.timestamps
    end

    add_index :chat_messages,
      [ :chat_session_id, :created_at ],
      name: "index_chat_messages_on_session_and_created_at"

    add_check_constraint :chat_messages,
      "char_length(btrim(content)) > 0",
      name: "chat_messages_content_not_blank"

    add_check_constraint :chat_messages,
      "prompt_tokens >= 0 AND candidate_tokens >= 0 " \
        "AND total_tokens >= 0",
      name: "chat_messages_token_counts_non_negative"

    add_check_constraint :chat_messages,
      "role = 'assistant' OR " \
        "(model IS NULL AND prompt_tokens = 0 " \
        "AND candidate_tokens = 0 AND total_tokens = 0)",
      name: "chat_messages_user_metadata_absent"

    create_table :chat_message_sources do |t|
      t.references :chat_message,
        null: false,
        foreign_key: { on_delete: :cascade }

      t.references :document,
        null: true,
        foreign_key: { on_delete: :nullify }

      t.references :document_chunk,
        null: true,
        foreign_key: { on_delete: :nullify }

      t.integer :rank, null: false
      t.string :document_title, null: false
      t.integer :page_number, null: false
      t.text :content, null: false
      t.float :cosine_distance, null: false

      t.timestamps
    end

    add_index :chat_message_sources,
      [ :chat_message_id, :rank ],
      unique: true,
      name: "index_chat_message_sources_unique_rank"

    add_index :chat_message_sources,
      [ :chat_message_id, :document_chunk_id ],
      unique: true,
      where: "document_chunk_id IS NOT NULL",
      name: "index_chat_message_sources_unique_chunk"

    add_check_constraint :chat_message_sources,
      "rank > 0",
      name: "chat_message_sources_rank_positive"

    add_check_constraint :chat_message_sources,
      "page_number > 0",
      name: "chat_message_sources_page_number_positive"

    add_check_constraint :chat_message_sources,
      "char_length(btrim(document_title)) > 0 " \
        "AND char_length(btrim(content)) > 0",
      name: "chat_message_sources_snapshots_not_blank"

    add_check_constraint :chat_message_sources,
      "cosine_distance >= 0 AND cosine_distance <= 2",
      name: "chat_message_sources_distance_in_range"
  end
end
