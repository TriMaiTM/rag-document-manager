require "test_helper"

class SemanticSearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Ai::RequestRateLimit.store.clear

    @workspace = workspaces(:one)
    sign_in_as users(:one)
  end

  test "requires authentication" do
    sign_out

    get workspace_semantic_search_url(@workspace)

    assert_redirected_to new_user_session_url
  end

  test "redirects the legacy semantic search screen to unified chat" do
    get workspace_semantic_search_url(@workspace)

    assert_redirected_to workspace_chat_sessions_url(@workspace)
    assert_equal "Tìm kiếm ngữ nghĩa đã được tích hợp vào cuộc trò chuyện.",
      flash[:notice]
  end

  test "does not call the legacy answer flow when a query is supplied" do
    factory = lambda do |**_arguments|
      flunk "Rag::AnswerQuestion should only be called from chat"
    end

    Rag::AnswerQuestion.stub(:new, factory) do
      get workspace_semantic_search_url(@workspace),
        params: { query: "Rails security" }
    end

    assert_redirected_to workspace_chat_sessions_url(@workspace)
  end

  test "member is redirected to unified chat" do
    sign_out
    sign_in_as users(:two)

    get workspace_semantic_search_url(@workspace)

    assert_redirected_to workspace_chat_sessions_url(@workspace)
  end

  test "outsider receives not found" do
    sign_out
    sign_in_as users(:four)

    get workspace_semantic_search_url(@workspace)

    assert_response :not_found
  end
end
