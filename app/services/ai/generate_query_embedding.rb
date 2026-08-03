module Ai
  class GenerateQueryEmbedding
    class Error < StandardError; end
    class InvalidQueryError < Error; end
    class InvalidResponseError < Error; end

    Result = Data.define(
      :vector,
      :model,
      :prompt_tokens,
      :total_tokens
    )

    def initialize(client: Ai::GeminiClient.new)
      @client = client
    end

    def call(query:)
      validate_query!(query)

      response = client.embed_query(input: query)
      vector = extract_vector(response.vectors)

      Result.new(
        vector: normalize(vector),
        model: Ai::EmbeddingConfig::MODEL,
        prompt_tokens: response.prompt_tokens,
        total_tokens: response.total_tokens
      )
    end

    private

    attr_reader :client

    def validate_query!(query)
      return if query.is_a?(String) && query.present?

      raise InvalidQueryError, "query must be a non-blank string"
    end

    def extract_vector(vectors)
      valid =
        vectors.is_a?(Array) &&
        vectors.one? &&
        vectors.first.is_a?(Array) &&
        vectors.first.size == Ai::EmbeddingConfig::DIMENSIONS

      return vectors.first if valid

      raise InvalidResponseError,
        "query embedding response has unexpected dimensions"
    end

    def normalize(vector)
      values = vector.map { |value| Float(value) }
      magnitude = Math.sqrt(values.sum { |value| value**2 })

      if magnitude.zero?
        raise InvalidResponseError,
          "query embedding response contains a zero vector"
      end

      values.map { |value| value / magnitude }
    rescue ArgumentError, TypeError => error
      raise InvalidResponseError,
        "query embedding response contains a non-numeric value: #{error.message}"
    end
  end
end
