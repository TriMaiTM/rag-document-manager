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

  def vector(value)
    Array.new(Ai::EmbeddingConfig::DIMENSIONS, value)
  end
end
