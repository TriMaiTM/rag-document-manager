require "json"
require "net/http"
require "timeout"
require "uri"

module Ai
  class GeminiClient
    class Error < StandardError; end

    class RequestError < Error
      attr_reader :status, :api_code

      def initialize(status:, api_code:, message:)
        @status = status
        @api_code = api_code

        super(message)
      end
    end

    class InvalidResponseError < Error; end

    class NetworkError < Error
      attr_reader :original_error

      def initialize(original_error)
        @original_error = original_error

        super(
          "Gemini network request failed: " \
            "#{original_error.class}: #{original_error.message}"
        )
      end
    end

    Response = Data.define(
      :vectors,
      :prompt_tokens,
      :total_tokens
    )

    GenerationResponse = Data.define(
      :text,
      :model,
      :prompt_tokens,
      :candidate_tokens,
      :total_tokens,
      :finish_reason
    )

    RETRYABLE_STATUSES = [ 500, 502, 503, 504 ].freeze
    NETWORK_ERRORS = [
      IOError,
      SystemCallError,
      Timeout::Error
    ].freeze
    DOCUMENT_TASK_TYPE = "RETRIEVAL_DOCUMENT"
    QUERY_TASK_TYPE = "RETRIEVAL_QUERY"

    def initialize(
      config: Rails.application.config.x.gemini,
      requester: nil,
      sleeper: Kernel.method(:sleep)
    )
      @config = config
      @requester = requester || method(:perform_request)
      @sleeper = sleeper
    end

    def embed_documents(inputs:)
      embed(inputs: inputs, task_type: DOCUMENT_TASK_TYPE)
    end

    def embed_query(input:)
      embed(inputs: [ input ], task_type: QUERY_TASK_TYPE)
    end

    def generate_content(
      system_instruction:,
      prompt:,
      max_output_tokens:
    )
      validate_api_key!

      uri = generation_endpoint_uri
      request = build_generation_request(
        uri,
        system_instruction,
        prompt,
        max_output_tokens
      )
      response = request_with_retries(
        uri,
        request,
        timeout: config.generation_timeout_seconds,
        max_retries: 0
      )

      parse_generation_response(response)
    end

    private

    attr_reader :config, :requester, :sleeper

    def embed(inputs:, task_type:)
      validate_api_key!

      uri = endpoint_uri
      request = build_request(uri, inputs, task_type)
      response = request_with_retries(uri, request)

      parse_response(response)
    end

    def validate_api_key!
      return if config.configured?

      raise Codexys::GeminiConfiguration::MissingApiKeyError,
        "Set GEMINI_API_KEY or credentials.gemini.api_key"
    end

    def endpoint_uri
      base_url = config.base_url.delete_suffix("/")
      model = config.embedding_model

      URI("#{base_url}/models/#{model}:batchEmbedContents")
    end

    def generation_endpoint_uri
      base_url = config.base_url.delete_suffix("/")

      URI(
        "#{base_url}/models/#{config.chat_model}:generateContent"
      )
    end

    def build_request(uri, inputs, task_type)
      Net::HTTP::Post.new(uri).tap do |request|
        request["Content-Type"] = "application/json"
        request["x-goog-api-key"] = config.api_key
        request.body = JSON.generate(
          request_body(inputs, task_type)
        )
      end
    end

    def request_body(inputs, task_type)
      {
        requests: inputs.map do |input|
          {
            model: "models/#{config.embedding_model}",
            content: {
              parts: [ { text: input } ]
            },
            taskType: task_type,
            outputDimensionality: config.embedding_dimensions
          }
        end
      }
    end

    def build_generation_request(
      uri,
      system_instruction,
      prompt,
      max_output_tokens
    )
      Net::HTTP::Post.new(uri).tap do |request|
        request["Content-Type"] = "application/json"
        request["x-goog-api-key"] = config.api_key
        request.body = JSON.generate(
          generation_request_body(
            system_instruction,
            prompt,
            max_output_tokens
          )
        )
      end
    end

    def generation_request_body(
      system_instruction,
      prompt,
      max_output_tokens
    )
      {
        systemInstruction: {
          parts: [ { text: system_instruction } ]
        },
        contents: [
          {
            role: "user",
            parts: [ { text: prompt } ]
          }
        ],
        generationConfig: {
          maxOutputTokens: max_output_tokens,
          responseMimeType: "text/plain"
        }
      }
    end

    def request_with_retries(
      uri,
      request,
      timeout: config.timeout_seconds,
      max_retries: config.max_retries
    )
      attempt = 0

      loop do
        begin
          response = requester.call(
            uri: uri,
            request: request,
            timeout: timeout
          )
        rescue *NETWORK_ERRORS => error
          if attempt >= max_retries
            raise NetworkError.new(error)
          end

          attempt += 1
          sleeper.call(0.25 * (2**(attempt - 1)))
          next
        end

        return response unless retryable_response?(response)
        return response if attempt >= max_retries

        attempt += 1
        sleeper.call(0.25 * (2**(attempt - 1)))
      end
    end

    def retryable_response?(response)
      RETRYABLE_STATUSES.include?(response.code.to_i)
    end

    def perform_request(uri:, request:, timeout:)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: timeout,
        read_timeout: timeout
      ) do |http|
        http.request(request)
      end
    end

    def parse_response(response)
      payload = JSON.parse(response.body)

      unless response.code.to_i.between?(200, 299)
        raise_request_error!(response, payload)
      end

      embeddings = payload.fetch("embeddings")
      usage = payload.fetch("usageMetadata", {})

      Response.new(
        vectors: embeddings.map { |item| item.fetch("values") },
        prompt_tokens: usage.fetch("promptTokenCount", 0),
        total_tokens: usage.fetch("totalTokenCount", 0)
      )
    rescue JSON::ParserError, KeyError, TypeError => error
      raise InvalidResponseError,
        "Invalid Gemini embedding response: #{error.message}"
    end

    def parse_generation_response(response)
      payload = JSON.parse(response.body)

      unless response.code.to_i.between?(200, 299)
        raise_request_error!(response, payload)
      end

      candidate = payload.fetch("candidates").first
      parts = candidate.fetch("content").fetch("parts")
      text = parts.filter_map { |part| part["text"] }.join("\n").strip
      usage = payload.fetch("usageMetadata", {})

      if text.blank?
        raise InvalidResponseError,
          "Gemini generation response does not contain text"
      end

      GenerationResponse.new(
        text: text,
        model: payload.fetch("modelVersion", config.chat_model),
        prompt_tokens: usage.fetch("promptTokenCount", 0),
        candidate_tokens: usage.fetch("candidatesTokenCount", 0),
        total_tokens: usage.fetch("totalTokenCount", 0),
        finish_reason: candidate["finishReason"]
      )
    rescue JSON::ParserError, KeyError, NoMethodError, TypeError => error
      raise InvalidResponseError,
        "Invalid Gemini generation response: #{error.message}"
    end

    def raise_request_error!(response, payload)
      error = payload.fetch("error", {})

      raise RequestError.new(
        status: response.code.to_i,
        api_code: error["status"],
        message: error.fetch(
          "message",
          "Gemini request failed with HTTP #{response.code}"
        )
      )
    end
  end
end
