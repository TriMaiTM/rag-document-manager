module Codexys
  class SemanticSearchConfiguration
    DEFAULT_MAX_COSINE_DISTANCE = 0.40

    attr_reader :max_cosine_distance

    def initialize(env: ENV)
      @max_cosine_distance = Float(
        env.fetch(
          "SEMANTIC_SEARCH_MAX_COSINE_DISTANCE",
          DEFAULT_MAX_COSINE_DISTANCE.to_s
        )
      )

      validate!
    end

    private

    def validate!
      return if max_cosine_distance.between?(0.0, 2.0)

      raise ArgumentError,
        "SEMANTIC_SEARCH_MAX_COSINE_DISTANCE must be between 0 and 2"
    end
  end
end

Rails.application.config.x.semantic_search =
  Codexys::SemanticSearchConfiguration.new
