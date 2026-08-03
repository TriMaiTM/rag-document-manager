require "test_helper"

class DocumentChunkTest < ActiveSupport::TestCase
  setup do
    @document = Document.new(
      workspace: workspaces(:one),
      uploaded_by: users(:one),
      title: "Chunk model test"
    )

    @document.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "chunk-test.pdf",
      content_type: Document::PDF_CONTENT_TYPE
    )

    @document.save!

    @chunk = @document.document_chunks.new(
      content: "Ruby on Rails favors convention.",
      page_number: 1,
      position: 1,
      processing_version: 1
    )
  end

  teardown do
    if @document.file.attached?
      @document.file.purge
    end
  end

  test "is valid before embedding is generated" do
    assert @chunk.valid?,
      @chunk.errors.full_messages.to_sentence
  end

  test "requires content" do
    @chunk.content = ""

    assert_not @chunk.valid?
    assert_includes @chunk.errors[:content],
      "can't be blank"
  end

  test "requires a positive page number" do
    @chunk.page_number = 0

    assert_not @chunk.valid?
    assert_includes @chunk.errors[:page_number],
      "must be greater than 0"
  end

  test "requires a positive position" do
    @chunk.position = 0

    assert_not @chunk.valid?
    assert_includes @chunk.errors[:position],
      "must be greater than 0"
  end

  test "position is unique within processing version" do
    @chunk.save!

    duplicate = @document.document_chunks.new(
      content: "Duplicated position.",
      page_number: 2,
      position: @chunk.position,
      processing_version: @chunk.processing_version
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:position],
      "has already been taken"
  end

  test "same position is allowed in a new processing version" do
    @chunk.save!

    reprocessed_chunk =
      @document.document_chunks.new(
        content: "Reprocessed content.",
        page_number: 1,
        position: @chunk.position,
        processing_version: 2
      )

    assert reprocessed_chunk.valid?,
      reprocessed_chunk.errors.full_messages.to_sentence
  end

  test "accepts embedding with complete metadata" do
    @chunk.embedding = embedding
    @chunk.embedding_provider =
      Ai::EmbeddingConfig::PROVIDER
    @chunk.embedding_model =
      Ai::EmbeddingConfig::MODEL
    @chunk.embedding_dimensions =
      Ai::EmbeddingConfig::DIMENSIONS

    assert @chunk.valid?,
      @chunk.errors.full_messages.to_sentence
  end

  test "rejects embedding without metadata" do
    @chunk.embedding = embedding

    assert_not @chunk.valid?

    assert_includes(
      @chunk.errors[:embedding_provider],
      "phải là openai"
    )

    assert_includes(
      @chunk.errors[:embedding_model],
      "phải là text-embedding-3-small"
    )
  end

  test "rejects metadata without embedding" do
    @chunk.embedding_provider =
      Ai::EmbeddingConfig::PROVIDER
    @chunk.embedding_model =
      Ai::EmbeddingConfig::MODEL
    @chunk.embedding_dimensions =
      Ai::EmbeddingConfig::DIMENSIONS

    assert_not @chunk.valid?

    assert_includes(
      @chunk.errors[:embedding],
      "phải có giá trị khi đã khai báo metadata"
    )
  end

  private

  def embedding
    Array.new(
      Ai::EmbeddingConfig::DIMENSIONS,
      0.01
    )
  end
end
