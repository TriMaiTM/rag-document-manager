require "test_helper"

class GeminiConfigurationTest < ActiveSupport::TestCase
  test "uses project defaults" do
    config = build_configuration

    assert_equal "google", config.provider
    assert_equal "gemini-embedding-001", config.embedding_model
    assert_equal 1_536, config.embedding_dimensions
    assert_equal(
      "https://generativelanguage.googleapis.com/v1beta",
      config.base_url
    )
    assert_equal 30, config.timeout_seconds
    assert_equal 2, config.max_retries
  end

  test "prefers API key from environment" do
    config = build_configuration(
      env: {
        "GEMINI_API_KEY" => "environment-key"
      },
      credentials: {
        gemini: {
          api_key: "credentials-key"
        }
      }
    )

    assert_equal "environment-key", config.api_key
  end

  test "falls back to Rails credentials" do
    config = build_configuration(
      credentials: {
        gemini: {
          api_key: "credentials-key"
        }
      }
    )

    assert_equal "credentials-key", config.api_key
  end

  test "allows a missing API key outside production" do
    config = build_configuration(environment: "test")

    assert_not config.configured?
    assert_same config, config.validate!
  end

  test "requires an API key in production" do
    config = build_configuration(environment: "production")

    assert_raises(
      Codexys::GeminiConfiguration::MissingApiKeyError
    ) do
      config.validate!
    end
  end

  test "reads request options from environment" do
    config = build_configuration(
      env: {
        "GEMINI_API_BASE_URL" => "https://example.test/v1beta",
        "GEMINI_TIMEOUT_SECONDS" => "45",
        "GEMINI_MAX_RETRIES" => "4"
      }
    )

    assert_equal "https://example.test/v1beta", config.base_url
    assert_equal 45, config.timeout_seconds
    assert_equal 4, config.max_retries
  end

  private

  def build_configuration(
    env: {},
    credentials: {},
    environment: "test"
  )
    Codexys::GeminiConfiguration.new(
      env: env,
      credentials: credentials,
      environment: environment
    )
  end
end
