require "test_helper"

class Ai::GeminiClientTest < ActiveSupport::TestCase
  HttpResponse = Data.define(:code, :body)

  test "sends a batch document embedding request" do
    captured = []

    requester = lambda do |uri:, request:, timeout:|
      captured << {
        uri: uri,
        request: request,
        timeout: timeout
      }

      successful_response
    end

    result = Ai::GeminiClient.new(
      config: configuration,
      requester: requester,
      sleeper: ->(_seconds) { }
    ).embed_documents(inputs: [ "First", "Second" ])

    call = captured.first
    body = JSON.parse(call[:request].body)

    assert_equal(
      "/v1beta/models/gemini-embedding-001:batchEmbedContents",
      call[:uri].path
    )
    assert_equal "test-key", call[:request]["x-goog-api-key"]
    assert_equal "application/json",
      call[:request]["Content-Type"]
    assert_equal 30, call[:timeout]

    assert_equal 2, body.fetch("requests").size
    assert_equal "First",
      body.dig("requests", 0, "content", "parts", 0, "text")
    assert_equal "RETRIEVAL_DOCUMENT",
      body.dig(
        "requests",
        0,
        "taskType"
      )
    assert_equal 1_536,
      body.dig(
        "requests",
        0,
        "outputDimensionality"
      )

    assert_equal 2, result.vectors.size
    assert_equal 8, result.prompt_tokens
    assert_equal 8, result.total_tokens
  end

  test "uses the retrieval query task for a search query" do
    captured_request = nil

    requester = lambda do |uri:, request:, timeout:|
      captured_request = request
      single_successful_response
    end

    result = Ai::GeminiClient.new(
      config: configuration,
      requester: requester,
      sleeper: ->(_seconds) { }
    ).embed_query(input: "How does Rails authentication work?")

    body = JSON.parse(captured_request.body)
    gemini_request = body.fetch("requests").sole

    assert_equal 1, result.vectors.size
    assert_equal "How does Rails authentication work?",
      gemini_request.dig("content", "parts", 0, "text")
    assert_equal "RETRIEVAL_QUERY",
      gemini_request.fetch("taskType")
    assert_equal 1_536,
      gemini_request.fetch("outputDimensionality")
  end

  test "generates grounded text content" do
    captured = nil

    requester = lambda do |uri:, request:, timeout:|
      captured = {
        uri: uri,
        request: request,
        timeout: timeout
      }
      generation_successful_response
    end

    result = Ai::GeminiClient.new(
      config: configuration,
      requester: requester,
      sleeper: ->(_seconds) { }
    ).generate_content(
      system_instruction: "Only use the supplied context.",
      prompt: "Question and context",
      max_output_tokens: 1_024
    )

    body = JSON.parse(captured[:request].body)

    assert_equal(
      "/v1beta/models/gemini-3.5-flash-lite:generateContent",
      captured[:uri].path
    )
    assert_equal "Only use the supplied context.",
      body.dig("systemInstruction", "parts", 0, "text")
    assert_equal "Question and context",
      body.dig("contents", 0, "parts", 0, "text")
    assert_equal 1_024,
      body.dig("generationConfig", "maxOutputTokens")
    assert_equal "text/plain",
      body.dig("generationConfig", "responseMimeType")
    assert_equal 60, captured[:timeout]
    assert_equal "Grounded answer [1]", result.text
    assert_equal "gemini-3.5-flash-lite-001", result.model
    assert_equal 20, result.prompt_tokens
    assert_equal 8, result.candidate_tokens
    assert_equal 28, result.total_tokens
    assert_equal "STOP", result.finish_reason
  end

  test "wraps a generation timeout as a Gemini network error" do
    requester = lambda do |**_arguments|
      raise Net::ReadTimeout, "execution expired"
    end

    client = Ai::GeminiClient.new(
      config: configuration,
      requester: requester,
      sleeper: ->(_seconds) { }
    )

    error = assert_raises(Ai::GeminiClient::NetworkError) do
      client.generate_content(
        system_instruction: "Use context only.",
        prompt: "Question and context",
        max_output_tokens: 512
      )
    end

    assert_instance_of Net::ReadTimeout, error.original_error
    assert_match(/Net::ReadTimeout/, error.message)
  end

  test "raises a structured API error" do
    response = HttpResponse.new(
      code: "429",
      body: {
        error: {
          status: "RESOURCE_EXHAUSTED",
          message: "Free tier quota exceeded"
        }
      }.to_json
    )

    error = assert_raises(Ai::GeminiClient::RequestError) do
      client_returning(response).embed_documents(inputs: [ "First" ])
    end

    assert_equal 429, error.status
    assert_equal "RESOURCE_EXHAUSTED", error.api_code
    assert_equal "Free tier quota exceeded", error.message
  end

  test "retries transient server errors" do
    responses = [
      HttpResponse.new(code: "503", body: "{}"),
      successful_response
    ]
    sleeps = []

    requester = lambda do |**_arguments|
      responses.shift
    end

    result = Ai::GeminiClient.new(
      config: configuration,
      requester: requester,
      sleeper: ->(seconds) { sleeps << seconds }
    ).embed_documents(inputs: [ "First", "Second" ])

    assert_equal 2, result.vectors.size
    assert_equal [ 0.25 ], sleeps
  end

  test "rejects malformed success responses" do
    response = HttpResponse.new(code: "200", body: "not-json")

    assert_raises(Ai::GeminiClient::InvalidResponseError) do
      client_returning(response).embed_documents(inputs: [ "First" ])
    end
  end

  test "requires an API key" do
    client = Ai::GeminiClient.new(
      config: configuration(api_key: nil),
      requester: ->(**_arguments) { successful_response }
    )

    assert_raises(
      Codexys::GeminiConfiguration::MissingApiKeyError
    ) do
      client.embed_documents(inputs: [ "First" ])
    end
  end

  private

  def client_returning(response)
    Ai::GeminiClient.new(
      config: configuration,
      requester: ->(**_arguments) { response },
      sleeper: ->(_seconds) { }
    )
  end

  def configuration(api_key: "test-key")
    env = {}
    env["GEMINI_API_KEY"] = api_key if api_key

    Codexys::GeminiConfiguration.new(
      env: env,
      credentials: {},
      environment: "test"
    )
  end

  def successful_response
    HttpResponse.new(
      code: "200",
      body: {
        embeddings: [
          { values: vector(0.1) },
          { values: vector(0.2) }
        ],
        usageMetadata: {
          promptTokenCount: 8,
          totalTokenCount: 8
        }
      }.to_json
    )
  end

  def single_successful_response
    HttpResponse.new(
      code: "200",
      body: {
        embeddings: [ { values: vector(0.1) } ],
        usageMetadata: {
          promptTokenCount: 4,
          totalTokenCount: 4
        }
      }.to_json
    )
  end

  def generation_successful_response
    HttpResponse.new(
      code: "200",
      body: {
        candidates: [
          {
            content: {
              parts: [ { text: "Grounded answer [1]" } ]
            },
            finishReason: "STOP"
          }
        ],
        usageMetadata: {
          promptTokenCount: 20,
          candidatesTokenCount: 8,
          totalTokenCount: 28
        },
        modelVersion: "gemini-3.5-flash-lite-001"
      }.to_json
    )
  end

  def vector(value)
    Array.new(Ai::EmbeddingConfig::DIMENSIONS, value)
  end
end
