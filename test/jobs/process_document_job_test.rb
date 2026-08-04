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

  test "delegates processing to the document orchestrator" do
    processor = Minitest::Mock.new
    processor.expect(:call, :processed)

    processor_factory = lambda do |document:|
      assert_equal @document, document
      processor
    end

    Documents::ProcessDocument.stub(:new, processor_factory) do
      ProcessDocumentJob.perform_now(@document)
    end

    processor.verify
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

  test "does not call the embedding API for a PDF over the page limit" do
    @document.file.purge
    @pdf_file.close!
    @pdf_file = build_pdf(
      page_count: Documents::ExtractText::MAX_PAGE_COUNT + 1
    )
    @document.file.attach(
      io: @pdf_file,
      filename: "too-many-pages.pdf",
      content_type: Document::PDF_CONTENT_TYPE
    )
    @document.save!

    generator_factory = lambda do
      flunk "Embedding generator must not be created"
    end

    Ai::GenerateEmbeddings.stub(:new, generator_factory) do
      assert_raises(
        Documents::ExtractText::PageLimitExceededError
      ) do
        ProcessDocumentJob.perform_now(@document)
      end
    end

    @document.reload

    assert @document.failed?
    assert_equal Documents::ExtractText::MAX_PAGE_COUNT + 1,
      @document.page_count
    assert_equal "page_limit_exceeded_error", @document.error_code
    assert_empty @document.document_chunks
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

  def build_pdf(page_count: 1)
    tempfile = Tempfile.new([ "process-document", ".pdf" ])
    tempfile.binmode

    pdf = Prawn::Document.new
    page_count.times do |index|
      pdf.text("Rails page #{index + 1} uses Active Record.")
      pdf.start_new_page unless index == page_count - 1
    end

    tempfile.write(pdf.render)
    tempfile.rewind
    tempfile
  end
end
