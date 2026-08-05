module SemanticSearch
    class RetrieveChunks
        class Error < StandardError; end
        class InvalidEmbeddingError < Error; end

        DEFAULT_LIMIT = 5
        MAX_LIMIT = 10

        def initialize(
            workspace:,
            embedding:,
            limit: DEFAULT_LIMIT,
            max_cosine_distance:
                Rails.application.config.x.semantic_search.max_cosine_distance
        )
            @workspace = workspace
            @embedding = embedding
            @limit = normalize_limit(limit)
            @max_cosine_distance = Float(max_cosine_distance)

            validate_max_cosine_distance!
        end

        def call
            validate_embedding!

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

        private

        attr_reader :workspace,
            :embedding,
            :limit,
            :max_cosine_distance

        def validate_embedding!
            valid =
                embedding.is_a?(Array) &&
                embedding.size == Ai::EmbeddingConfig::DIMENSIONS &&
                embedding.all? do |value|
                    value.is_a?(Numeric) &&
                        value.respond_to?(:finite?) &&
                        value.finite?
                end
            return if valid

            raise InvalidEmbeddingError,
                "query embedding must contain" \
                "#{Ai::EmbeddingConfig::DIMENSIONS} finite numbers"
        end

        def normalize_limit(value)
            Integer(value).clamp(1, MAX_LIMIT)
        rescue ArgumentError, TypeError
            DEFAULT_LIMIT
        end

        def validate_max_cosine_distance!
            return if max_cosine_distance.between?(0.0, 2.0)

            raise ArgumentError,
                "max_cosine_distance must be between 0 and 2"
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
