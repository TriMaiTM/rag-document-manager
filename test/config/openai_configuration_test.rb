require "test_helper"

class OpenaiConfigurationTest < ActiveSupport::TestCase
  test "uses project defaults" do
    config = build_configuration

    assert_equal "openai", config.provider
    assert_equal(
      "text-embedding-3-small",
      config.embedding_model
    )
    assert_equal 1_536, config.embedding_dimensions
    assert_equal "gpt-5.6-terra", config.chat_model
    assert_equal 30, config.timeout_seconds
    assert_equal 2, config.max_retries
  end

  test "prefers API key from environment" do
    config = build_configuration(
      env: {
        "OPENAI_API_KEY" => "environment-key"
      },
      credentials: {
        openai: {
          api_key: "credentials-key"
        }
      }
    )

    assert_equal "environment-key", config.api_key
  end

  test "falls back to Rails credentials" do
    config = build_configuration(
      credentials: {
        openai: {
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
      Codexys::OpenaiConfiguration::MissingApiKeyError
    ) do
      config.validate!
    end
  end

  test "reads model and request options from environment" do
    config = build_configuration(
      env: {
        "OPENAI_CHAT_MODEL" => "custom-model",
        "OPENAI_TIMEOUT_SECONDS" => "45",
        "OPENAI_MAX_RETRIES" => "4"
      }
    )

    assert_equal "custom-model", config.chat_model
    assert_equal 45, config.timeout_seconds
    assert_equal 4, config.max_retries
  end

  private

  def build_configuration(
    env: {},
    credentials: {},
    environment: "test"
  )
    Codexys::OpenaiConfiguration.new(
      env: env,
      credentials: credentials,
      environment: environment
    )
  end
end
