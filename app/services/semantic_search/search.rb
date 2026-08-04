module SemanticSearch
  class Search
    class Error < StandardError; end
    class InvalidQueryError < Error; end

    Result = Data.define(
      :query,
      :chunks,
      :embedding_milliseconds,
      :vector_search_milliseconds
    ) do
      def initialize(
        query:,
        chunks:,
        embedding_milliseconds: 0.0,
        vector_search_milliseconds: 0.0
      )
        super
      end
    end

    MIN_QUERY_LENGTH = 2
    MAX_QUERY_LENGTH = 500
    DEFAULT_LIMIT = 5
    MAX_LIMIT = 10
    DEFAULT_CLOCK = lambda do
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
    def self.normalize_query!(query)
      normalized_query = query.to_s.squish

      if normalized_query.length < MIN_QUERY_LENGTH
        raise InvalidQueryError,
          "Nội dung tìm kiếm phải có ít nhất #{MIN_QUERY_LENGTH} ký tự."
      end

      if normalized_query.length > MAX_QUERY_LENGTH
        raise InvalidQueryError,
          "Nội dung tìm kiếm không được vượt quá #{MAX_QUERY_LENGTH} ký tự."
      end

      normalized_query
    end

    def initialize(
      workspace:,
      query:,
      generator: Ai::GenerateQueryEmbedding.new,
      limit: DEFAULT_LIMIT,
      max_cosine_distance:
        Rails.application.config.x.semantic_search.max_cosine_distance,
      clock: DEFAULT_CLOCK
    )
      @workspace = workspace
      @query = query
      @generator = generator
      @limit = normalize_limit(limit)
      @max_cosine_distance = Float(max_cosine_distance)
      @clock = clock

      validate_max_cosine_distance!
    end

    def call
      normalized_query = self.class.normalize_query!(query)

      embedding, embedding_milliseconds = measure do
        generator.call(query: normalized_query).vector
      end
      chunks, vector_search_milliseconds = measure do
        nearest_chunks(embedding)
      end

      Result.new(
        query: normalized_query,
        chunks: chunks,
        embedding_milliseconds: embedding_milliseconds,
        vector_search_milliseconds: vector_search_milliseconds
      )
    end

    private

    attr_reader :workspace,
      :query,
      :generator,
      :limit,
      :max_cosine_distance,
      :clock

    def normalize_limit(value)
      [ Integer(value), MAX_LIMIT ].min.clamp(1, MAX_LIMIT)
    rescue ArgumentError, TypeError
      DEFAULT_LIMIT
    end

    def validate_max_cosine_distance!
      return if max_cosine_distance.between?(0.0, 2.0)

      raise ArgumentError,
        "max_cosine_distance must be between 0 and 2"
    end

    def measure
      started_at = clock.call
      value = yield

      [ value, ((clock.call - started_at) * 1_000).round(3) ]
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
          chunk.neighbor_distance <= max_cosine_distance
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
