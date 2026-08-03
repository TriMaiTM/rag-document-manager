require "test_helper"
require "prawn"
require "tempfile"

class ProcessDocumentJobTest < ActiveJob::TestCase
  setup do
    @pdf_file = build_pdf

    @document = Document.new(
      workspace: workspaces(:one),
      uploaded_by: users(:one),
      title: "Process document job"
    )

    @document.file.attach(
      io: @pdf_file,
      filename: "process-document-job.pdf",
      content_type: Document::PDF_CONTENT_TYPE
    )

    @document.save!
  end

  teardown do
    @document.file.purge if @document.file.attached?
    @pdf_file.close!
  end

  test "prepares chunks before generating embeddings" do
    calls = []
    prepare_service = service_recording(calls, :prepare)
    embed_service = service_recording(calls, :embed)

    prepare_factory = lambda do |document:|
      assert_equal @document, document
      prepare_service
    end

    embed_factory = lambda do |document:|
      assert_equal @document, document
      embed_service
    end

    Documents::PrepareChunks.stub(:new, prepare_factory) do
      Documents::EmbedChunks.stub(:new, embed_factory) do
        ProcessDocumentJob.perform_now(@document)
      end
    end

    assert_equal [ :prepare, :embed ], calls
  end

  test "processes a PDF through chunks and embeddings" do
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

    generator_factory = -> { generator }

    Ai::GenerateEmbeddings.stub(:new, generator_factory) do
      ProcessDocumentJob.perform_now(@document)
    end

    @document.reload
    chunks = @document.document_chunks.order(:position)

    assert @document.completed?
    assert_predicate chunks, :any?
    assert chunks.all? { |chunk| chunk.embedding.present? }
  end

  test "does not generate embeddings when chunk preparation fails" do
    prepare_service = Object.new
    prepare_service.define_singleton_method(:call) do
      raise Documents::PrepareChunks::EmptyChunksError,
        "No chunks"
    end

    embed_service = Minitest::Mock.new

    prepare_factory = ->(document:) { prepare_service }
    embed_factory = ->(document:) { embed_service }

    Documents::PrepareChunks.stub(:new, prepare_factory) do
      Documents::EmbedChunks.stub(:new, embed_factory) do
        assert_raises(
          Documents::PrepareChunks::EmptyChunksError
        ) do
          ProcessDocumentJob.perform_now(@document)
        end
      end
    end

    embed_service.verify
  end

  test "processes a retry without duplicating chunks in the new version" do
    @document.document_chunks.create!(
      content: "Content from the failed version",
      page_number: 1,
      position: 1,
      processing_version: 1
    )
    @document.update!(status: :failed)

    Documents::RetryProcessing.new(document: @document).call

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

    Ai::GenerateEmbeddings.stub(:new, -> { generator }) do
      ProcessDocumentJob.perform_now(@document)
    end

    @document.reload
    current_chunks = @document.document_chunks.where(
      processing_version: @document.processing_version
    )

    assert @document.completed?
    assert_equal 2, @document.processing_version
    assert_equal [ 1, 2 ],
      @document.document_chunks.distinct.order(:processing_version)
        .pluck(:processing_version)
    assert_equal current_chunks.count,
      current_chunks.distinct.count(:position)
    assert current_chunks.all? { |chunk| chunk.embedding.present? }
  end

  private

  def build_pdf
    tempfile = Tempfile.new([ "process-document", ".pdf" ])
    tempfile.binmode

    pdf = Prawn::Document.new
    pdf.text("Rails uses Active Record for database access.")

    tempfile.write(pdf.render)
    tempfile.rewind
    tempfile
  end

  def service_recording(calls, name)
    Object.new.tap do |service|
      service.define_singleton_method(:call) do
        calls << name
      end
    end
  end
end
