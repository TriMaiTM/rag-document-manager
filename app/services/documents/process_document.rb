module Documents
  class ProcessDocument
    Result = Data.define(
      :document,
      :preparation,
      :embedding
    )

    def initialize(
      document:,
      prepare_chunks: Documents::PrepareChunks,
      embed_chunks: Documents::EmbedChunks,
      lifecycle: Documents::Lifecycle.new(document: document)
    )
      @document = document
      @prepare_chunks = prepare_chunks
      @embed_chunks = embed_chunks
      @lifecycle = lifecycle
    end

    def call
      processing_version = lifecycle.start_processing!
      preparation = prepare_chunks.new(document: document).call
      embedding = embed_chunks.new(document: document).call

      Result.new(
        document: document.reload,
        preparation: preparation,
        embedding: embedding
      )
    rescue StandardError => error
      mark_failed!(error, processing_version)
      raise
    end

    private

    attr_reader :document,
      :prepare_chunks,
      :embed_chunks,
      :lifecycle

    def mark_failed!(error, processing_version)
      return unless processing_version

      lifecycle.fail!(
        error: error,
        expected_processing_version: processing_version
      )
    end
  end
end
