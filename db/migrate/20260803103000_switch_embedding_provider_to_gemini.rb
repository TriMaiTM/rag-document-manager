class SwitchEmbeddingProviderToGemini < ActiveRecord::Migration[8.1]
  CONSTRAINT_NAME =
    "document_chunks_embedding_metadata_consistent"

  def up
    replace_constraint(
      provider: "google",
      model: "gemini-embedding-001"
    )
  end

  def down
    replace_constraint(
      provider: "openai",
      model: "text-embedding-3-small"
    )
  end

  private

  def replace_constraint(provider:, model:)
    remove_check_constraint :document_chunks,
      name: CONSTRAINT_NAME

    expression = <<~SQL.squish
      (
        embedding IS NULL
        AND embedding_provider IS NULL
        AND embedding_model IS NULL
        AND embedding_dimensions IS NULL
      )
      OR
      (
        embedding IS NOT NULL
        AND embedding_provider = '#{provider}'
        AND embedding_model = '#{model}'
        AND embedding_dimensions = 1536
      )
    SQL

    add_check_constraint :document_chunks,
      expression,
      name: CONSTRAINT_NAME
  end
end
