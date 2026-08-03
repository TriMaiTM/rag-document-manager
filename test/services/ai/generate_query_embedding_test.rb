require "test_helper"

class Ai::GenerateQueryEmbeddingTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :input

    def initialize(response)
      @response = response
    end

    def embed_query(input:)
      @input = input
      @response
    end
  end

  test "generates one normalized query embedding" do
    vector = Array.new(Ai::EmbeddingConfig::DIMENSIONS, 0.0)
    vector[0] = 3.0
    vector[1] = 4.0
    client = FakeClient.new(response(vectors: [ vector ]))

    result = Ai::GenerateQueryEmbedding.new(client: client).call(
      query: "How does Rails authentication work?"
    )

    assert_equal "How does Rails authentication work?", client.input
    assert_equal Ai::EmbeddingConfig::MODEL, result.model
    assert_equal 4, result.prompt_tokens
    assert_equal 4, result.total_tokens
    assert_in_delta 0.6, result.vector[0]
    assert_in_delta 0.8, result.vector[1]
  end

  test "rejects a blank query" do
    generator = Ai::GenerateQueryEmbedding.new(
      client: FakeClient.new(response(vectors: []))
    )

    assert_raises(Ai::GenerateQueryEmbedding::InvalidQueryError) do
      generator.call(query: "")
    end
  end

  test "rejects an unexpected response" do
    generator = Ai::GenerateQueryEmbedding.new(
      client: FakeClient.new(response(vectors: [ [ 0.1, 0.2 ] ]))
    )

    assert_raises(Ai::GenerateQueryEmbedding::InvalidResponseError) do
      generator.call(query: "Rails")
    end
  end

  private

  def response(vectors:)
    Ai::GeminiClient::Response.new(
      vectors: vectors,
      prompt_tokens: 4,
      total_tokens: 4
    )
  end
end
