require "test_helper"

class SemanticSearchConfigurationTest < ActiveSupport::TestCase
  test "uses the tuned default threshold" do
    config = Codexys::SemanticSearchConfiguration.new(env: {})

    assert_in_delta 0.40, config.max_cosine_distance
  end

  test "reads the threshold from the environment" do
    config = Codexys::SemanticSearchConfiguration.new(
      env: { "SEMANTIC_SEARCH_MAX_COSINE_DISTANCE" => "0.35" }
    )

    assert_in_delta 0.35, config.max_cosine_distance
  end

  test "rejects a threshold outside the cosine distance range" do
    assert_raises(ArgumentError) do
      Codexys::SemanticSearchConfiguration.new(
        env: { "SEMANTIC_SEARCH_MAX_COSINE_DISTANCE" => "2.1" }
      )
    end
  end
end
