require "test_helper"

module SemanticSearch
  class HybridSearchTest < ActiveSupport::TestCase
    setup do
      @workspace = workspaces(:one)
    end

    test "executes hybrid search and returns result with chunks and sources" do
      query = "Codexys RAG"
      result = HybridSearch.new(
        workspace: @workspace,
        query: query,
        limit: 5
      ).call

      assert_respond_to result, :chunks
      assert_respond_to result, :sources
      assert_equal "Codexys RAG", result.query
    end
  end
end
