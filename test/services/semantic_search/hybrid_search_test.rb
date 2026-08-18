require "test_helper"

module SemanticSearch
  class HybridSearchTest < ActiveSupport::TestCase
    class FakeGenerator
      def call(query:)
        Ai::GenerateQueryEmbedding::Result.new(
          vector: Array.new(Ai::EmbeddingConfig::DIMENSIONS, 0.0),
          model: Ai::EmbeddingConfig::MODEL,
          prompt_tokens: 3,
          total_tokens: 3
        )
      end
    end

    setup do
      @workspace = workspaces(:one)
    end

    test "executes hybrid search and returns result with chunks and sources" do
      query = "Codexys RAG"
      result = HybridSearch.new(
        workspace: @workspace,
        query: query,
        generator: FakeGenerator.new,
        limit: 5
      ).call

      assert_respond_to result, :chunks
      assert_respond_to result, :sources
      assert_equal "Codexys RAG", result.query
    end
  end
end
