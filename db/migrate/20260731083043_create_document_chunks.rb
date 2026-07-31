class CreateDocumentChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :document_chunks do |t|
      t.references :document,
        null: false,
        foreign_key: { on_delete: :cascade }

      t.text :content, null: false
      t.integer :page_number, null: false
      t.integer :position, null: false

      t.integer :processing_version,
        null: false,
        default: 1

      t.vector :embedding, limit: 1_536

      t.string :embedding_provider
      t.string :embedding_model
      t.integer :embedding_dimensions

      t.timestamps
    end

    add_index :document_chunks,
      [
        :document_id,
        :processing_version,
        :position
      ],
      unique: true,
      name: "index_document_chunks_unique_position"

    add_index :document_chunks,
      [
        :document_id,
        :processing_version,
        :page_number
      ],
      name: "index_document_chunks_on_document_page"

    add_index :document_chunks,
      :embedding,
      using: :hnsw,
      opclass: :vector_cosine_ops,
      name: "index_document_chunks_on_embedding"

    add_check_constraint :document_chunks,
      "char_length(btrim(content)) > 0",
      name: "document_chunks_content_not_blank"

    add_check_constraint :document_chunks,
      "page_number > 0",
      name: "document_chunks_page_number_positive"

    add_check_constraint :document_chunks,
      "position > 0",
      name: "document_chunks_position_positive"

    add_check_constraint :document_chunks,
      "processing_version > 0",
      name: "document_chunks_processing_version_positive"

    embedding_metadata_constraint = <<~SQL.squish
      (
        embedding IS NULL
        AND embedding_provider IS NULL
        AND embedding_model IS NULL
        AND embedding_dimensions IS NULL
      )
      OR
      (
        embedding IS NOT NULL
        AND embedding_provider = 'openai'
        AND embedding_model = 'text-embedding-3-small'
        AND embedding_dimensions = 1536
      )
    SQL

    add_check_constraint :document_chunks,
      embedding_metadata_constraint,
      name: "document_chunks_embedding_metadata_consistent"
  end
end
