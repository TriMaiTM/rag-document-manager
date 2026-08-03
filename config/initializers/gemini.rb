module Codexys
  class GeminiConfiguration
    class MissingApiKeyError < StandardError; end

    DEFAULT_BASE_URL =
      "https://generativelanguage.googleapis.com/v1beta"
    DEFAULT_CHAT_MODEL = "gemini-3.5-flash-lite"
    DEFAULT_TIMEOUT_SECONDS = 30
    DEFAULT_GENERATION_TIMEOUT_SECONDS = 60
    DEFAULT_MAX_RETRIES = 2

    attr_reader :api_key,
      :base_url,
      :chat_model,
      :generation_timeout_seconds,
      :timeout_seconds,
      :max_retries

    def initialize(
      env: ENV,
      credentials: Rails.application.credentials,
      environment: Rails.env
    )
      @environment = environment.to_s

      @api_key =
        env["GEMINI_API_KEY"].presence ||
        credentials.dig(:gemini, :api_key).presence

      @base_url = env.fetch(
        "GEMINI_API_BASE_URL",
        DEFAULT_BASE_URL
      )

      @chat_model = env.fetch(
        "GEMINI_CHAT_MODEL",
        DEFAULT_CHAT_MODEL
      )

      @timeout_seconds = Integer(
        env.fetch(
          "GEMINI_TIMEOUT_SECONDS",
          DEFAULT_TIMEOUT_SECONDS.to_s
        ),
        10
      )

      @generation_timeout_seconds = Integer(
        env.fetch(
          "GEMINI_GENERATION_TIMEOUT_SECONDS",
          DEFAULT_GENERATION_TIMEOUT_SECONDS.to_s
        ),
        10
      )

      @max_retries = Integer(
        env.fetch(
          "GEMINI_MAX_RETRIES",
          DEFAULT_MAX_RETRIES.to_s
        ),
        10
      )

      validate_options!
    end

    def provider
      Ai::EmbeddingConfig::PROVIDER
    end

    def embedding_model
      Ai::EmbeddingConfig::MODEL
    end

    def embedding_dimensions
      Ai::EmbeddingConfig::DIMENSIONS
    end

    def configured?
      api_key.present?
    end

    def validate!
      return self unless production?
      return self if configured?

      raise MissingApiKeyError,
        "Set GEMINI_API_KEY or credentials.gemini.api_key"
    end

    private

    def production?
      @environment == "production"
    end

    def validate_options!
      if base_url.blank?
        raise ArgumentError,
          "GEMINI_API_BASE_URL must not be blank"
      end

      if chat_model.blank?
        raise ArgumentError,
          "GEMINI_CHAT_MODEL must not be blank"
      end

      if timeout_seconds <= 0
        raise ArgumentError,
          "GEMINI_TIMEOUT_SECONDS must be greater than zero"
      end

      if generation_timeout_seconds <= 0
        raise ArgumentError,
          "GEMINI_GENERATION_TIMEOUT_SECONDS must be greater than zero"
      end

      return unless max_retries.negative?

      raise ArgumentError,
        "GEMINI_MAX_RETRIES must be zero or greater"
    end
  end
end

Rails.application.config.x.gemini =
  Codexys::GeminiConfiguration.new.validate!
