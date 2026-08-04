module Documents
  class EmbedChunks
    class Error < StandardError; end
    class InvalidStatusError < Error; end
    class EmptyChunksError < Error; end
    class StaleProcessingVersionError < Error; end
    class IncompleteEmbeddingsError < Error; end

    DEFAULT_BATCH_SIZE = 64
    Result = Data.define(
      :document,
      :chunks,
      :processing_version,
      :prompt_tokens,
      :total_tokens
    )

    def initialize(
      document:,
      generator: Ai::GenerateEmbeddings.new,
      batch_size: DEFAULT_BATCH_SIZE
    )
      @document = document
      @generator = generator
      @batch_size = batch_size

      validate_batch_size!
    end

    def call
      processing_version = nil
      prompt_tokens = 0
      total_tokens = 0

      processing_version = start_embedding!
      chunks = current_chunks(processing_version).to_a

      validate_chunks!(chunks)

      chunks.reject { |chunk| chunk.embedding.present? }
        .each_slice(batch_size) do |batch|
          response = generator.call(
            inputs: batch.map(&:content)
          )

          persist_batch!(
            batch,
            response.vectors,
            processing_version
          )

          prompt_tokens += response.prompt_tokens
          total_tokens += response.total_tokens
        end

      complete!(processing_version)

      Result.new(
        document: document.reload,
        chunks: current_chunks(processing_version).to_a,
        processing_version: processing_version,
        prompt_tokens: prompt_tokens,
        total_tokens: total_tokens
      )
    rescue StandardError => error
      mark_failed!(error, processing_version)
      raise
    end

    private

    attr_reader :document, :generator, :batch_size

    def validate_batch_size!
      return if batch_size.is_a?(Integer) && batch_size.positive?

      raise ArgumentError, "batch_size must be a positive integer"
    end

    def start_embedding!
      lifecycle.start_processing!
    rescue Documents::Lifecycle::InvalidTransitionError => error
      raise InvalidStatusError, error.message
    end

    def current_chunks(processing_version)
      document.document_chunks
        .where(processing_version: processing_version)
        .order(:position)
    end

    def validate_chunks!(chunks)
      return if chunks.any?

      raise EmptyChunksError,
        "Document has no chunks for the current processing version"
    end

    def persist_batch!(chunks, vectors, processing_version)
      unless chunks.size == vectors.size
        raise IncompleteEmbeddingsError,
          "Embedding count does not match chunk count"
      end

      document.with_lock do
        validate_processing_version!(processing_version)

        DocumentChunk.transaction do
          chunks.zip(vectors).each do |chunk, vector|
            stored_chunk = current_chunks(processing_version)
              .find(chunk.id)

            stored_chunk.update!(
              embedding: vector,
              embedding_provider: Ai::EmbeddingConfig::PROVIDER,
              embedding_model: Ai::EmbeddingConfig::MODEL,
              embedding_dimensions: Ai::EmbeddingConfig::DIMENSIONS
            )
          end
        end
      end
    end

    def complete!(processing_version)
      lifecycle.complete!(
        expected_processing_version: processing_version
      ) do
        if current_chunks(processing_version)
            .where(embedding: nil)
            .exists?
          raise IncompleteEmbeddingsError,
            "Not all chunks have an embedding"
        end
      end
    rescue Documents::Lifecycle::StaleProcessingVersionError => error
      raise StaleProcessingVersionError, error.message
    end

    def validate_processing_version!(expected_version)
      return if document.processing_version == expected_version

      raise StaleProcessingVersionError,
        "Document started a newer processing version"
    end

    def mark_failed!(error, processing_version)
      return unless processing_version

      lifecycle.fail!(
        error: error,
        expected_processing_version: processing_version
      )
    end

    def lifecycle
      @lifecycle ||= Documents::Lifecycle.new(document: document)
    end
  end
end
