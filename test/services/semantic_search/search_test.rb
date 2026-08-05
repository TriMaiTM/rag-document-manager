require "test_helper"

class SemanticSearch::SearchTest < ActiveSupport::TestCase
  class FakeGenerator
    attr_reader :query

    def initialize(vector)
      @vector = vector
    end

    def call(query:)
      @query = query

      Ai::GenerateQueryEmbedding::Result.new(
        vector: @vector,
        model: Ai::EmbeddingConfig::MODEL,
        prompt_tokens: 3,
        total_tokens: 3
      )
    end
  end

  setup do
    @documents = []
    @query_vector = vector(1.0, 0.0)
  end

  teardown do
    @documents.each do |document|
      document.file.purge if document.file.attached?
    end
  end

  test "returns nearest current chunks from completed workspace documents" do
    document = create_document(workspaces(:one), status: :completed)
    relevant = create_chunk(document, vector(1.0, 0.0), position: 1)
    related = create_chunk(document, vector(0.8, 0.6), position: 2)

    other_workspace_document = create_document(
      workspaces(:two),
      status: :completed
    )
    create_chunk(
      other_workspace_document,
      vector(1.0, 0.0),
      position: 1
    )

    failed_document = create_document(workspaces(:one), status: :failed)
    create_chunk(failed_document, vector(1.0, 0.0), position: 1)

    create_chunk(
      document,
      vector(1.0, 0.0),
      position: 1,
      processing_version: document.processing_version + 1
    )

    generator = FakeGenerator.new(@query_vector)
    clock_values = [ 0.0, 0.4, 1.0, 1.01 ]
    result = SemanticSearch::Search.new(
      workspace: workspaces(:one),
      query: "  Rails   authentication  ",
      generator: generator,
      clock: -> { clock_values.shift }
    ).call

    assert_equal "Rails authentication", generator.query
    assert_equal "Rails authentication", result.query
    assert_equal [ relevant.id, related.id ], result.chunks.map(&:id)
    assert_in_delta 0.0, result.chunks.first.neighbor_distance
    assert_in_delta 0.2, result.chunks.second.neighbor_distance
    assert_equal [ 1, 2 ],
      result.sources.map(&:rank)

    source = result.sources.first

    assert_equal relevant.id, source.chunk_id
    assert_equal document.id, source.document_id
    assert_equal document.title, source.document_title
    assert_equal relevant.page_number, source.page_number
    assert_equal relevant.content, source.content
    assert_in_delta 0.0, source.cosine_distance
    assert_in_delta 1.0, source.similarity
    assert_not_respond_to source, :embedding
    assert_in_delta 400.0, result.embedding_milliseconds
    assert_in_delta 10.0, result.vector_search_milliseconds
  end

  test "reports insufficient context when every chunk exceeds threshold" do
    document = create_document(
      workspaces(:one),
      status: :completed
    )

    create_chunk(
      document,
      vector(0.0, 1.0),
      position: 1
    )

    result = SemanticSearch::Search.new(
      workspace: workspaces(:one),
      query: "Rails",
      generator: FakeGenerator.new(@query_vector)
    ).call

    assert result.insufficient_context?
    assert_not result.sufficient_context?
    assert_empty result.chunks
    assert_empty result.sources
  end

  test "limits the number of results" do
    document = create_document(workspaces(:one), status: :completed)

    3.times do |index|
      create_chunk(
        document,
        vector(1.0, index.fdiv(10)),
        position: index + 1
      )
    end

    result = SemanticSearch::Search.new(
      workspace: workspaces(:one),
      query: "Rails",
      generator: FakeGenerator.new(@query_vector),
      limit: 2
    ).call

    assert_equal 2, result.chunks.size
  end

  test "rejects chunks outside the relevance threshold" do
    document = create_document(workspaces(:one), status: :completed)
    accepted = create_chunk(
      document,
      vector(0.61, 0.7924),
      position: 1
    )
    create_chunk(
      document,
      vector(0.59, 0.8074),
      position: 2
    )

    result = SemanticSearch::Search.new(
      workspace: workspaces(:one),
      query: "Rails",
      generator: FakeGenerator.new(@query_vector)
    ).call

    assert_equal [ accepted.id ], result.chunks.map(&:id)
    assert_operator result.chunks.sole.neighbor_distance,
      :<=,
      0.40
  end

  test "rejects a query that is too short" do
    generator = FakeGenerator.new(@query_vector)

    assert_raises(SemanticSearch::Search::InvalidQueryError) do
      SemanticSearch::Search.new(
        workspace: workspaces(:one),
        query: " ",
        generator: generator
      ).call
    end

    assert_nil generator.query
  end

  private

  def create_document(workspace, status:)
    document = Document.new(
      workspace: workspace,
      uploaded_by: workspace.memberships.first.user,
      title: "Semantic search #{SecureRandom.hex(4)}",
      status: status
    )

    document.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "semantic-search-#{SecureRandom.hex(4)}.pdf",
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
      content: "Chunk #{position} from #{document.title}",
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
    Array.new(Ai::EmbeddingConfig::DIMENSIONS, 0.0).tap do |embedding|
      embedding[0] = first
      embedding[1] = second
    end
  end
end
