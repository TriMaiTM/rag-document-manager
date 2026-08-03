require "test_helper"

class Documents::PrepareChunksTest <
    ActiveSupport::TestCase
  setup do
    @document = Document.new(
      workspace: workspaces(:one),
      uploaded_by: users(:one),
      title: "Prepare chunks test"
    )

    @document.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "prepare-chunks.pdf",
      content_type: Document::PDF_CONTENT_TYPE
    )

    @document.save!
  end

  teardown do
    if @document.file.attached?
      @document.file.purge
    end
  end

  test "extracts chunks and stores them in order" do
    @document.update!(
      status: :failed,
      error_code: "old_error",
      error_message: "Old error"
    )

    result = process(chunks: sample_chunks)

    @document.reload

    assert @document.processing?
    assert_nil @document.error_code
    assert_nil @document.error_message

    assert_equal 2, result.chunks.size
    assert_equal 1, result.processing_version

    assert_equal(
      [ 1, 2 ],
      result.chunks.map(&:position)
    )

    assert_equal(
      [ 1, 2 ],
      result.chunks.map(&:page_number)
    )

    assert_equal(
      [
        "First Rails chunk.",
        "Second Rails chunk."
      ],
      result.chunks.map(&:content)
    )
  end

  test "running twice does not duplicate chunks" do
    process(chunks: sample_chunks)

    assert_equal 2,
      @document.document_chunks.count

    process(chunks: sample_chunks)

    assert_equal 2,
      @document.document_chunks.count

    assert_equal(
      [ 1, 2 ],
      @document.document_chunks
        .order(:position)
        .pluck(:position)
    )
  end

  test "preserves chunks from older processing versions" do
    @document.update!(processing_version: 2)

    @document.document_chunks.create!(
      content: "Old version chunk.",
      page_number: 1,
      position: 1,
      processing_version: 1
    )

    process(chunks: sample_chunks)

    assert_equal(
      [ 1, 2 ],
      @document.document_chunks
        .order(:processing_version)
        .pluck(:processing_version)
        .uniq
    )

    assert_equal 1,
      @document.document_chunks
        .where(processing_version: 1)
        .count

    assert_equal 2,
      @document.document_chunks
        .where(processing_version: 2)
        .count
  end

  test "rolls back replacement when a chunk is invalid" do
    @document.document_chunks.create!(
      content: "Existing chunk.",
      page_number: 1,
      position: 1,
      processing_version: 1
    )

    invalid_chunks = [
      chunk(
        position: 1,
        page_number: 1,
        content: "Temporary valid chunk."
      ),
      chunk(
        position: 2,
        page_number: 1,
        content: ""
      )
    ]

    assert_raises(
      ActiveRecord::RecordInvalid
    ) do
      process(chunks: invalid_chunks)
    end

    @document.reload

    assert @document.failed?
    assert_equal "record_invalid",
      @document.error_code

    assert_equal(
      [ "Existing chunk." ],
      @document.document_chunks.pluck(:content)
    )
  end

  test "marks document failed when no chunks are produced" do
    assert_raises(
      Documents::PrepareChunks::EmptyChunksError
    ) do
      process(chunks: [])
    end

    @document.reload

    assert @document.failed?
    assert_equal "empty_chunks_error",
      @document.error_code

    assert_equal 0,
      @document.document_chunks.count
  end

  test "does not process a completed document" do
    @document.update!(status: :completed)

    assert_raises(
      Documents::PrepareChunks::InvalidStatusError
    ) do
      process(chunks: sample_chunks)
    end

    assert @document.reload.completed?
  end

  test "does not overwrite a newer processing version" do
    stale_extractor =
      extractor_that_increments_version

    service = Documents::PrepareChunks.new(
      document: @document,
      extractor: stale_extractor,
      chunker: chunker_returning(sample_chunks)
    )

    assert_raises(
      Documents::PrepareChunks::
        StaleProcessingVersionError
    ) do
      service.call
    end

    @document.reload

    assert_equal 2,
      @document.processing_version

    assert @document.processing?
    assert_nil @document.error_code
    assert_equal 0,
      @document.document_chunks.count
  end

  private

  def process(chunks:)
    Documents::PrepareChunks.new(
      document: @document,
      extractor: extractor_returning(sample_pages),
      chunker: chunker_returning(chunks)
    ).call
  end

  def sample_pages
    [
      Documents::ExtractText::Page.new(
        number: 1,
        text: "First page."
      ),
      Documents::ExtractText::Page.new(
        number: 2,
        text: "Second page."
      )
    ]
  end

  def sample_chunks
    [
      chunk(
        position: 1,
        page_number: 1,
        content: "First Rails chunk."
      ),
      chunk(
        position: 2,
        page_number: 2,
        content: "Second Rails chunk."
      )
    ]
  end

  def chunk(position:, page_number:, content:)
    Documents::ChunkText::Chunk.new(
      position: position,
      page_number: page_number,
      content: content
    )
  end

  def extractor_returning(pages)
    Class.new do
      define_method(:initialize) do |document:|
        @document = document
      end

      define_method(:call) do
        pages
      end
    end
  end

  def chunker_returning(chunks)
    Class.new do
      define_method(:initialize) do |pages:|
        @pages = pages
      end

      define_method(:call) do
        chunks
      end
    end
  end

  def extractor_that_increments_version
    pages = sample_pages

    Class.new do
      define_method(:initialize) do |document:|
        @document = document
      end

      define_method(:call) do
        @document.update_column(
          :processing_version,
          @document.processing_version + 1
        )

        pages
      end
    end
  end
end
