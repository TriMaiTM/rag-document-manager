require "test_helper"

class Documents::EmbedChunksTest < ActiveSupport::TestCase
  class FakeEmbeddingError < StandardError; end

  class FakeGenerator
    attr_reader :batches

    def initialize(error: nil)
      @error = error
      @batches = []
    end

    def call(inputs:)
      raise @error if @error

      batches << inputs

      vectors = inputs.map.with_index do |input, index|
        value = (input.length + index).fdiv(10_000)
        Array.new(Ai::EmbeddingConfig::DIMENSIONS, value)
      end

      Ai::GenerateEmbeddings::Result.new(
        vectors: vectors,
        model: Ai::EmbeddingConfig::MODEL,
        prompt_tokens: inputs.size * 10,
        total_tokens: inputs.size * 10
      )
    end
  end

  setup do
    @document = build_document
    create_chunks(3)
  end

  teardown do
    @document.file.purge if @document.file.attached?
  end

  test "embeds current chunks in batches and completes document" do
    generator = FakeGenerator.new

    result = Documents::EmbedChunks.new(
      document: @document,
      generator: generator,
      batch_size: 2
    ).call

    assert @document.reload.completed?
    assert_nil @document.error_code
    assert_nil @document.error_message

    assert_equal 2, generator.batches.size
    assert_equal 30, result.prompt_tokens
    assert_equal 30, result.total_tokens
    assert_equal 3, result.chunks.size

    result.chunks.each do |chunk|
      assert_equal Ai::EmbeddingConfig::DIMENSIONS,
        chunk.embedding.size
      assert_equal Ai::EmbeddingConfig::PROVIDER,
        chunk.embedding_provider
      assert_equal Ai::EmbeddingConfig::MODEL,
        chunk.embedding_model
      assert_equal Ai::EmbeddingConfig::DIMENSIONS,
        chunk.embedding_dimensions
    end
  end

  test "skips chunks that already have an embedding" do
    embedded_chunk = @document.document_chunks.order(:position).first
    embedded_chunk.update!(embedding_attributes(vector(0.4)))

    generator = FakeGenerator.new

    Documents::EmbedChunks.new(
      document: @document,
      generator: generator
    ).call

    embedded_chunk.reload

    assert_equal 1, generator.batches.size
    assert_equal 2, generator.batches.first.size
    assert_equal vector(0.4), embedded_chunk.embedding.to_a
  end

  test "marks document failed when embedding generation fails" do
    generator = FakeGenerator.new(
      error: FakeEmbeddingError.new("Gemini unavailable")
    )

    assert_raises(FakeEmbeddingError) do
      Documents::EmbedChunks.new(
        document: @document,
        generator: generator
      ).call
    end

    @document.reload

    assert @document.failed?
    assert_equal "fake_embedding_error", @document.error_code
    assert_equal "Gemini unavailable", @document.error_message
  end

  test "stores the Gemini API error code" do
    error = Ai::GeminiClient::RequestError.new(
      status: 429,
      api_code: "RESOURCE_EXHAUSTED",
      message: "Free tier quota exceeded"
    )

    generator = FakeGenerator.new(error: error)

    assert_raises(Ai::GeminiClient::RequestError) do
      Documents::EmbedChunks.new(
        document: @document,
        generator: generator
      ).call
    end

    @document.reload

    assert @document.failed?
    assert_equal "resource_exhausted", @document.error_code
    assert_equal "Free tier quota exceeded", @document.error_message
  end

  test "resumes a failed document with partial embeddings" do
    first_chunk = @document.document_chunks.order(:position).first
    first_chunk.update!(embedding_attributes(vector(0.5)))

    @document.update!(
      status: :failed,
      error_code: "old_error",
      error_message: "Old error"
    )

    generator = FakeGenerator.new

    Documents::EmbedChunks.new(
      document: @document,
      generator: generator
    ).call

    assert @document.reload.completed?
    assert_nil @document.error_code
    assert_equal 2, generator.batches.first.size
  end

  test "rejects a document without current chunks" do
    @document.document_chunks.delete_all

    assert_raises(Documents::EmbedChunks::EmptyChunksError) do
      Documents::EmbedChunks.new(
        document: @document,
        generator: FakeGenerator.new
      ).call
    end

    assert @document.reload.failed?
    assert_equal "empty_chunks_error", @document.error_code
  end

  test "does not overwrite a newer processing version" do
    document = @document
    generator = FakeGenerator.new

    generator.define_singleton_method(:call) do |inputs:|
      result = super(inputs: inputs)
      document.update_column(
        :processing_version,
        document.processing_version + 1
      )
      result
    end

    assert_raises(
      Documents::EmbedChunks::StaleProcessingVersionError
    ) do
      Documents::EmbedChunks.new(
        document: @document,
        generator: generator
      ).call
    end

    @document.reload

    assert_equal 2, @document.processing_version
    assert @document.processing?
    assert_nil @document.error_code
  end

  test "requires a processing or failed document" do
    @document.update!(status: :completed)

    assert_raises(Documents::EmbedChunks::InvalidStatusError) do
      Documents::EmbedChunks.new(
        document: @document,
        generator: FakeGenerator.new
      ).call
    end

    assert @document.reload.completed?
  end

  private

  def build_document
    document = Document.new(
      workspace: workspaces(:one),
      uploaded_by: users(:one),
      title: "Embed chunks test",
      status: :processing
    )

    document.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "embed-chunks.pdf",
      content_type: Document::PDF_CONTENT_TYPE
    )

    document.save!
    document
  end

  def create_chunks(count)
    count.times do |index|
      @document.document_chunks.create!(
        content: "Rails chunk #{index + 1}",
        page_number: 1,
        position: index + 1,
        processing_version: @document.processing_version
      )
    end
  end

  def embedding_attributes(embedding)
    {
      embedding: embedding,
      embedding_provider: Ai::EmbeddingConfig::PROVIDER,
      embedding_model: Ai::EmbeddingConfig::MODEL,
      embedding_dimensions: Ai::EmbeddingConfig::DIMENSIONS
    }
  end

  def vector(value)
    Array.new(Ai::EmbeddingConfig::DIMENSIONS, value)
  end
end
