require "test_helper"

class SemanticSearch::RetrieveChunksTest < ActiveSupport::TestCase
  setup do
    @documents = []
    @query_embedding = vector(1.0, 0.0)
  end

  teardown do
    @documents.each do |document|
      document.file.purge if document.file.attached?
    end
  end

  test "returns nearest chunks only from the requested workspace" do
    document = create_document(
      workspaces(:one),
      status: :completed
    )
    relevant = create_chunk(
      document,
      vector(1.0, 0.0),
      position: 1
    )
    related = create_chunk(
      document,
      vector(0.8, 0.6),
      position: 2
    )

    other_document = create_document(
      workspaces(:two),
      status: :completed
    )
    create_chunk(
      other_document,
      vector(1.0, 0.0),
      position: 1
    )

    failed_document = create_document(
      workspaces(:one),
      status: :failed
    )
    create_chunk(
      failed_document,
      vector(1.0, 0.0),
      position: 1
    )

    result = SemanticSearch::RetrieveChunks.new(
      workspace: workspaces(:one),
      embedding: @query_embedding
    ).call

    assert_equal [ relevant.id, related.id ],
      result.map(&:id)
  end

  test "ignores chunks from an old processing version" do
    document = create_document(
      workspaces(:one),
      status: :completed
    )

    current_chunk = create_chunk(
      document,
      vector(0.9, 0.1),
      position: 1
    )
    create_chunk(
      document,
      vector(1.0, 0.0),
      position: 1,
      processing_version: document.processing_version + 1
    )

    result = SemanticSearch::RetrieveChunks.new(
      workspace: workspaces(:one),
      embedding: @query_embedding
    ).call

    assert_equal [ current_chunk.id ], result.map(&:id)
  end

  test "rejects an embedding with incorrect dimensions" do
    error = assert_raises(
      SemanticSearch::RetrieveChunks::InvalidEmbeddingError
    ) do
      SemanticSearch::RetrieveChunks.new(
        workspace: workspaces(:one),
        embedding: [ 0.1, 0.2 ]
      ).call
    end

    assert_match(/1536/, error.message)
  end

  private

  def create_document(workspace, status:)
    document = Document.new(
      workspace: workspace,
      uploaded_by: workspace.memberships.first.user,
      title: "Retrieval #{SecureRandom.hex(4)}",
      status: status
    )
    document.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "retrieval.pdf",
      content_type: Document::PDF_CONTENT_TYPE
    )
    document.save!

    @documents << document
    document
  end

  def create_chunk(
    document,
    embedding,
    position:,
    processing_version: document.processing_version
  )
    document.document_chunks.create!(
      content: "Retrieval chunk #{position}",
      page_number: 1,
      position: position,
      processing_version: processing_version,
      embedding: embedding,
      embedding_provider: Ai::EmbeddingConfig::PROVIDER,
      embedding_model: Ai::EmbeddingConfig::MODEL,
      embedding_dimensions: Ai::EmbeddingConfig::DIMENSIONS
    )
  end

  def vector(first, second)
    Array.new(
      Ai::EmbeddingConfig::DIMENSIONS,
      0.0
    ).tap do |embedding|
      embedding[0] = first
      embedding[1] = second
    end
  end
end
