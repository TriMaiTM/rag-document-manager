module Codexys
    class OpenaiConfiguration
        class MissingApiKeyError < StandardError; end

        DEFAULT_CHAT_MODEL = "gpt-5.6-terra"
        DEFAULT_TIMEOUT_SECONDS = 30
        DEFAULT_MAX_RETRIES = 2

        attr_reader :api_key,
                    :chat_model,
                    :timeout_seconds,
                    :max_retries

        def initialize(
            env: ENV,
            credentials: Rails.application.credentials,
            environment: Rails.env
        )
            @environment = environment.to_s

            @api_key =
                env["OPENAI_API_KEY"].presence ||
                credentials.dig(:openai, :api_key).presence

            @chat_model =
                env.fetch(
                    "OPENAI_CHAT_MODEL",
                    DEFAULT_CHAT_MODEL
                )

            @timeout_seconds =
                Integer(
                    env.fetch(
                        "OPENAI_TIMEOUT_SECONDS",
                        DEFAULT_TIMEOUT_SECONDS.to_s
                    ),
                    10
                )

            @max_retries =
                Integer(
                    env.fetch(
                        "OPENAI_MAX_RETRIES",
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
                "Set OPENAI_API_KEY of credentials.openai.api_key"
        end

        private

        def production?
            @environment == "production"
        end

        def validate_options!
            if chat_model.blank?
                raise ArgumentError,
                    "OPENAI_CHAT_MODEL must not be blank"
            end

            if timeout_seconds <= 0
                raise ArgumentError,
                    "OPENAI_TIMEOUT_SECONDS must be greater than zero"
            end

            return unless max_retries.negative?

            raise ArgumentError,
                "OPENAI_MAX_RETRIES must be zero or greater"
        end
    end
end

Rails.application.config.x.openai =
    Codexys::OpenaiConfiguration.new.validate!
