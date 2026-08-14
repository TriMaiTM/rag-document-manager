class DocumentChunk < ApplicationRecord
  belongs_to :document,
    inverse_of: :document_chunks

  has_many :chat_message_sources, dependent: :nullify

  has_neighbors :embedding

  validates :content, presence: true

  def self.keyword_search(query)
    keywords = query.to_s.scan(/\p{L}+|\p{N}+/).select { |w| w.length >= 2 }
    return none if keywords.empty?

    conditions = keywords.map { "content ILIKE ?" }.join(" OR ")
    values = keywords.map { |kw| "%#{sanitize_sql_like(kw)}%" }

    where(conditions, *values)
  end

  validates :page_number,
    numericality: {
      only_integer: true,
      greater_than: 0
    }

  validates :position,
    numericality: {
      only_integer: true,
      greater_than: 0
    },
    uniqueness: {
      scope: [
        :document_id,
        :processing_version
      ]
    }

  validates :processing_version,
    numericality: {
      only_integer: true,
      greater_than: 0
    }

  validate :embedding_metadata_must_be_consistent

  private

  def embedding_metadata_must_be_consistent
    if embedding.nil?
      validate_metadata_is_absent
    else
      validate_metadata_matches_configuration
    end
  end

  def validate_metadata_is_absent
    metadata = [
      embedding_provider,
      embedding_model,
      embedding_dimensions
    ]

    return if metadata.all?(&:nil?)

    errors.add(
      :embedding,
      "phải có giá trị khi đã khai báo metadata"
    )
  end

  def validate_metadata_matches_configuration
    unless embedding_provider == Ai::EmbeddingConfig::PROVIDER
      errors.add(
        :embedding_provider,
        "phải là #{Ai::EmbeddingConfig::PROVIDER}"
      )
    end

    unless embedding_model == Ai::EmbeddingConfig::MODEL
      errors.add(
        :embedding_model,
        "phải là #{Ai::EmbeddingConfig::MODEL}"
      )
    end

    unless embedding_dimensions ==
        Ai::EmbeddingConfig::DIMENSIONS
      errors.add(
        :embedding_dimensions,
        "phải là #{Ai::EmbeddingConfig::DIMENSIONS}"
      )
    end
  end
end
