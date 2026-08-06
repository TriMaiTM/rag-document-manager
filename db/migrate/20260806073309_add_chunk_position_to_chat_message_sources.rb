class AddChunkPositionToChatMessageSources <
  ActiveRecord::Migration[8.1]
  def up
    add_column :chat_message_sources,
      :chunk_position,
      :integer

    execute <<~SQL
      UPDATE chat_message_sources
      SET chunk_position = document_chunks.position
      FROM document_chunks
      WHERE chat_message_sources.document_chunk_id =
        document_chunks.id
    SQL

    add_check_constraint :chat_message_sources,
      "chunk_position IS NULL OR chunk_position > 0",
      name: "chat_message_sources_chunk_position_positive"
  end

  def down
    remove_check_constraint :chat_message_sources,
      name: "chat_message_sources_chunk_position_positive"

    remove_column :chat_message_sources,
      :chunk_position
  end
end
