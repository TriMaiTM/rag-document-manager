require "test_helper"

class SemanticSearch::SourceExcerptTest <
    ActiveSupport::TestCase
  DocumentStub = Data.define(:id, :title)

  ChunkStub = Data.define(
    :id,
    :document,
    :page_number,
    :content,
    :neighbor_distance
  )

  test "builds an immutable excerpt from a chunk" do
    document = DocumentStub.new(
      id: 10,
      title: "Rails Guide"
    )
    chunk = ChunkStub.new(
      id: 20,
      document: document,
      page_number: 3,
      content: "Active Record connects Rails to databases.",
      neighbor_distance: 0.2
    )

    source = SemanticSearch::SourceExcerpt.from_chunk(
      chunk,
      rank: 1
    )

    assert_equal 1, source.rank
    assert_equal 20, source.chunk_id
    assert_equal 10, source.document_id
    assert_equal "Rails Guide", source.document_title
    assert_equal 3, source.page_number
    assert_equal chunk.content, source.content
    assert_in_delta 0.2, source.cosine_distance
    assert_in_delta 0.8, source.similarity
  end

  test "normalizes and limits excerpt content" do
    document = DocumentStub.new(
      id: 10,
      title: "Long document"
    )
    chunk = ChunkStub.new(
      id: 20,
      document: document,
      page_number: 1,
      content: "Rails\n\n#{'a' * 600}",
      neighbor_distance: 0.1
    )

    source = SemanticSearch::SourceExcerpt.from_chunk(
      chunk,
      rank: 1
    )

    assert_operator source.content.length,
      :<=,
      SemanticSearch::SourceExcerpt::MAX_CONTENT_LENGTH
    assert_not_includes source.content, "\n"
    assert source.content.end_with?("…")
  end
end
