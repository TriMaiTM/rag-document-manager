module SemanticSearch
  class Search
    class Error < StandardError; end
    class InvalidQueryError < Error; end

    Result = Data.define(:query, :chunks)

    MIN_QUERY_LENGTH = 2
    MAX_QUERY_LENGTH = 500
    DEFAULT_LIMIT = 5
    MAX_LIMIT = 10
    MAX_COSINE_DISTANCE = 0.65

    def initialize(
      workspace:,
      query:,
      generator: Ai::GenerateQueryEmbedding.new,
      limit: DEFAULT_LIMIT
    )
      @workspace = workspace
      @query = query
      @generator = generator
      @limit = normalize_limit(limit)
    end

    def call
      normalized_query = query.to_s.squish
      validate_query!(normalized_query)

      embedding = generator.call(query: normalized_query).vector
      chunks = nearest_chunks(embedding)

      Result.new(query: normalized_query, chunks: chunks)
    end

    private

    attr_reader :workspace, :query, :generator, :limit

    def validate_query!(normalized_query)
      if normalized_query.length < MIN_QUERY_LENGTH
        raise InvalidQueryError,
          "Nội dung tìm kiếm phải có ít nhất #{MIN_QUERY_LENGTH} ký tự."
      end

      return if normalized_query.length <= MAX_QUERY_LENGTH

      raise InvalidQueryError,
        "Nội dung tìm kiếm không được vượt quá #{MAX_QUERY_LENGTH} ký tự."
    end

    def normalize_limit(value)
      [ Integer(value), MAX_LIMIT ].min.clamp(1, MAX_LIMIT)
    rescue ArgumentError, TypeError
      DEFAULT_LIMIT
    end

    def nearest_chunks(embedding)
      candidates
        .nearest_neighbors(
          :embedding,
          embedding,
          distance: "cosine"
        )
        .limit(limit)
        .preload(:document)
        .to_a
        .select do |chunk|
          chunk.neighbor_distance <= MAX_COSINE_DISTANCE
        end
    end

    def candidates
      DocumentChunk
        .joins(:document)
        .where(
          documents: {
            workspace_id: workspace.id,
            status: Document.statuses.fetch(:completed)
          }
        )
        .where(
          "document_chunks.processing_version = " \
            "documents.processing_version"
        )
        .where.not(embedding: nil)
        .where(
          embedding_provider: Ai::EmbeddingConfig::PROVIDER,
          embedding_model: Ai::EmbeddingConfig::MODEL,
          embedding_dimensions: Ai::EmbeddingConfig::DIMENSIONS
        )
    end
  end
end
