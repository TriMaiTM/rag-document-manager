require "test_helper"

class Ai::GenerateEmbeddingsTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :inputs

    def initialize(response)
      @response = response
    end

    def embed_documents(inputs:)
      @inputs = inputs
      @response
    end
  end

  test "generates normalized embeddings in input order" do
    first_vector = vector_with(3.0, 4.0)
    second_vector = vector_with(5.0, 12.0)

    client = FakeClient.new(
      response(vectors: [ first_vector, second_vector ])
    )

    result = Ai::GenerateEmbeddings.new(client: client).call(
      inputs: [ "First chunk", "Second chunk" ]
    )

    assert_equal [ "First chunk", "Second chunk" ], client.inputs
    assert_equal Ai::EmbeddingConfig::MODEL, result.model
    assert_equal 12, result.prompt_tokens
    assert_equal 12, result.total_tokens

    assert_in_delta 0.6, result.vectors.first[0]
    assert_in_delta 0.8, result.vectors.first[1]
    assert_in_delta 5.0 / 13.0, result.vectors.second[0]
    assert_in_delta 12.0 / 13.0, result.vectors.second[1]
  end

  test "requires at least one non-blank input" do
    generator = Ai::GenerateEmbeddings.new(
      client: FakeClient.new(response(vectors: []))
    )

    assert_raises(Ai::GenerateEmbeddings::EmptyInputError) do
      generator.call(inputs: [])
    end

    assert_raises(Ai::GenerateEmbeddings::EmptyInputError) do
      generator.call(inputs: [ "" ])
    end
  end

  test "rejects a response with the wrong vector count" do
    generator = Ai::GenerateEmbeddings.new(
      client: FakeClient.new(
        response(vectors: [ vector_with(1.0, 0.0) ])
      )
    )

    assert_raises(Ai::GenerateEmbeddings::InvalidResponseError) do
      generator.call(inputs: [ "First", "Second" ])
    end
  end

  test "rejects vectors with unexpected dimensions" do
    generator = Ai::GenerateEmbeddings.new(
      client: FakeClient.new(
        response(vectors: [ [ 0.1, 0.2 ] ])
      )
    )

    assert_raises(Ai::GenerateEmbeddings::InvalidResponseError) do
      generator.call(inputs: [ "First" ])
    end
  end

  test "rejects a zero vector" do
    generator = Ai::GenerateEmbeddings.new(
      client: FakeClient.new(
        response(
          vectors: [
            Array.new(Ai::EmbeddingConfig::DIMENSIONS, 0.0)
          ]
        )
      )
    )

    assert_raises(Ai::GenerateEmbeddings::InvalidResponseError) do
      generator.call(inputs: [ "First" ])
    end
  end

  private

  def response(vectors:)
    Ai::GeminiClient::Response.new(
      vectors: vectors,
      prompt_tokens: 12,
      total_tokens: 12
    )
  end

  def vector_with(first, second)
    Array.new(Ai::EmbeddingConfig::DIMENSIONS, 0.0).tap do |vector|
      vector[0] = first
      vector[1] = second
    end
  end
end
