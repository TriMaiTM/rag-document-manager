module Ai
  class GenerateEmbeddings
    class Error < StandardError; end
    class EmptyInputError < Error; end
    class InvalidResponseError < Error; end

    Result = Data.define(
      :vectors,
      :model,
      :prompt_tokens,
      :total_tokens
    )

    def initialize(client: Ai::GeminiClient.new)
      @client = client
    end

    def call(inputs:)
      validate_inputs!(inputs)

      response = client.embed_documents(inputs: inputs)
      vectors = response.vectors

      validate_count!(vectors, inputs.size)
      validate_dimensions!(vectors)

      Result.new(
        vectors: vectors.map { |vector| normalize(vector) },
        model: Ai::EmbeddingConfig::MODEL,
        prompt_tokens: response.prompt_tokens,
        total_tokens: response.total_tokens
      )
    end

    private

    attr_reader :client

    def validate_inputs!(inputs)
      valid =
        inputs.is_a?(Array) &&
        inputs.any? &&
        inputs.all? { |input| input.is_a?(String) && input.present? }

      return if valid

      raise EmptyInputError,
        "inputs must contain at least one non-blank string"
    end

    def validate_count!(vectors, expected_count)
      return if vectors.size == expected_count

      raise InvalidResponseError,
        "embedding response count does not match inputs"
    end

    def validate_dimensions!(vectors)
      valid = vectors.all? do |vector|
        vector.is_a?(Array) &&
          vector.size == Ai::EmbeddingConfig::DIMENSIONS
      end

      return if valid

      raise InvalidResponseError,
        "embedding response has unexpected dimensions"
    end

    def normalize(vector)
      values = vector.map { |value| Float(value) }
      magnitude = Math.sqrt(values.sum { |value| value**2 })

      if magnitude.zero?
        raise InvalidResponseError,
          "embedding response contains a zero vector"
      end

      values.map { |value| value / magnitude }
    rescue ArgumentError, TypeError => error
      raise InvalidResponseError,
        "embedding response contains a non-numeric value: #{error.message}"
    end
  end
end
