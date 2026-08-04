require "test_helper"
require "prawn"
require "tempfile"

class Documents::ProcessDocumentTest < ActiveSupport::TestCase
  setup do
    @pdf_file = build_pdf
    @document = build_document(@pdf_file)
  end

  teardown do
    @document.file.purge if @document.file.attached?
    @pdf_file.close!
  end

  test "composes preparation and embedding in order" do
    calls = []
    preparation = Object.new
    embedding = Object.new

    prepare_service = service_returning(
      calls: calls,
      name: :prepare,
      result: preparation
    )
    embed_service = service_returning(
      calls: calls,
      name: :embed,
      result: embedding
    )

    result = Documents::ProcessDocument.new(
      document: @document,
      prepare_chunks: prepare_service,
      embed_chunks: embed_service
    ).call

    assert_equal [ :prepare, :embed ], calls
    assert_same @document, result.document
    assert_same preparation, result.preparation
    assert_same embedding, result.embedding
  end

  test "moves a valid upload to completed with embedded chunks" do
    result = process_with_fake_embeddings

    @document.reload
    chunks = @document.document_chunks.order(:position)

    assert @document.completed?
    assert_predicate @document.processing_started_at, :present?
    assert_predicate @document.completed_at, :present?
    assert_nil @document.failed_at
    assert_predicate chunks, :any?
    assert chunks.all? { |chunk| chunk.embedding.present? }
    assert_equal chunks.to_a, result.embedding.chunks
  end

  test "marks an unexpected preparation failure safely" do
    prepare_service = Class.new do
      define_method(:initialize) do |document:|
        @document = document
      end

      define_method(:call) do
        raise RuntimeError, "Parser crashed"
      end
    end
    embed_service = Class.new do
      define_method(:initialize) do |document:|
        raise "Embedding must not start for #{document.id}"
      end
    end

    assert_raises(RuntimeError, "Parser crashed") do
      Documents::ProcessDocument.new(
        document: @document,
        prepare_chunks: prepare_service,
        embed_chunks: embed_service
      ).call
    end

    @document.reload

    assert @document.failed?
    assert_equal "runtime_error", @document.error_code
    assert_equal "Parser crashed", @document.error_message
    assert_predicate @document.failed_at, :present?
    assert_nil @document.completed_at
  end

  test "reprocessing a failed version does not duplicate chunks" do
    process_with_fake_embeddings
    original_count = @document.document_chunks.count

    @document.update!(status: :failed)
    process_with_fake_embeddings

    @document.reload
    current_chunks = @document.document_chunks.where(
      processing_version: @document.processing_version
    )

    assert @document.completed?
    assert_equal original_count, current_chunks.count
    assert_equal current_chunks.count,
      current_chunks.distinct.count(:position)
  end

  private

  def process_with_fake_embeddings
    generator = Object.new
    generator.define_singleton_method(:call) do |inputs:|
      vectors = inputs.map do
        Array.new(Ai::EmbeddingConfig::DIMENSIONS, 0.01)
      end

      Ai::GenerateEmbeddings::Result.new(
        vectors: vectors,
        model: Ai::EmbeddingConfig::MODEL,
        prompt_tokens: inputs.size,
        total_tokens: inputs.size
      )
    end

    embed_service = Class.new(Documents::EmbedChunks) do
      define_method(:initialize) do |document:|
        super(document: document, generator: generator)
      end
    end

    Documents::ProcessDocument.new(
      document: @document,
      embed_chunks: embed_service
    ).call
  end

  def service_returning(calls:, name:, result:)
    Class.new do
      define_method(:initialize) do |document:|
        @document = document
      end

      define_method(:call) do
        calls << name
        result
      end
    end
  end

  def build_document(file)
    document = Document.new(
      workspace: workspaces(:one),
      uploaded_by: users(:one),
      title: "Process document service"
    )
    document.file.attach(
      io: file,
      filename: "process-document-service.pdf",
      content_type: Document::PDF_CONTENT_TYPE
    )
    document.save!
    document
  end

  def build_pdf
    tempfile = Tempfile.new([ "process-document", ".pdf" ])
    tempfile.binmode

    pdf = Prawn::Document.new
    pdf.text("Rails uses Active Record for database access.")
    tempfile.write(pdf.render)
    tempfile.rewind
    tempfile
  end
end
