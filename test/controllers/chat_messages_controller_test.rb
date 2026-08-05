require "test_helper"

class ChatMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Ai::RequestRateLimit.store.clear

    @workspace = workspaces(:one)
    @user = users(:one)
    @chat_session = ChatSession.create!(
      workspace: @workspace,
      user: @user,
      title: "Rails security"
    )

    sign_in_as @user
  end

  test "appends a question through the chat service" do
    service = Object.new
    service.define_singleton_method(:call) do
      Chat::Ask::Result.new(
        chat_session: nil,
        user_message: nil,
        assistant_message: nil,
        rag_result: nil,
        error: nil
      )
    end
    factory = ->(**_arguments) { service }

    Chat::Ask.stub(:new, factory) do
      post workspace_chat_session_chat_messages_url(
        @workspace,
        @chat_session
      ), params: { question: "What about CSRF?" }
    end

    assert_redirected_to workspace_chat_session_url(
      @workspace,
      @chat_session
    )
  end

  test "redirects a blank follow-up with an error" do
    post workspace_chat_session_chat_messages_url(
      @workspace,
      @chat_session
    ), params: { question: " " }

    assert_redirected_to workspace_chat_session_url(
      @workspace,
      @chat_session
    )
    assert_equal(
      "Nội dung tìm kiếm phải có ít nhất 2 ký tự.",
      flash[:alert]
    )
  end

  test "redirects to history when a persisted follow-up fails" do
    error = Ai::GenerateQueryEmbedding::InvalidResponseError.new(
      "Invalid embedding response"
    )
    service = Object.new
    service.define_singleton_method(:call) do
      Chat::Ask::Result.new(
        chat_session: nil,
        user_message: nil,
        assistant_message: nil,
        rag_result: nil,
        error: error
      )
    end

    Chat::Ask.stub(:new, ->(**_arguments) { service }) do
      post workspace_chat_session_chat_messages_url(
        @workspace,
        @chat_session
      ), params: { question: "What about CSRF?" }
    end

    assert_redirected_to workspace_chat_session_url(
      @workspace,
      @chat_session
    )
    assert_equal Chat::Ask::FAILURE_ANSWER, flash[:alert]
  end

  test "cannot append to another member's session" do
    other_session = ChatSession.create!(
      workspace: @workspace,
      user: users(:two),
      title: "Member private chat"
    )

    post workspace_chat_session_chat_messages_url(
      @workspace,
      other_session
    ), params: { question: "Forbidden question" }

    assert_response :not_found
  end

  test "shares the burst limit across all AI controllers" do
    calls = 0
    service = Object.new
    result = Chat::Ask::Result.new(
      chat_session: @chat_session,
      user_message: nil,
      assistant_message: nil,
      rag_result: nil,
      error: nil
    )
    service.define_singleton_method(:call) do
      calls += 1
      result
    end

    Chat::Ask.stub(:new, ->(**_arguments) { service }) do
      3.times do
        post workspace_chat_sessions_url(@workspace),
          params: { question: "New chat question" }
        assert_response :redirect
      end

      2.times do
        post workspace_chat_session_chat_messages_url(
          @workspace,
          @chat_session
        ), params: { question: "Follow-up question" }
        assert_response :redirect
      end
    end

    get workspace_semantic_search_url(
      @workspace,
      query: "Semantic query"
    )

    assert_response :too_many_requests
    assert_equal Ai::RequestRateLimit::BURST_LIMIT, calls
    assert_equal "60", response.headers["Retry-After"]
    assert_select "h1", "Bạn đang gửi câu hỏi quá nhanh"
  end

  test "retries an owned failed assistant message" do
    question = @chat_session.chat_messages.create!(
      role: :user,
      content: "What is semantic search?"
    )
    failed_message = @chat_session.chat_messages.create!(
      role: :assistant,
      status: :failed,
      question_message: question,
      content: Chat::Ask::FAILURE_ANSWER,
      error_code: "network_error"
    )

    result = Chat::RetryAnswer::Result.new(
      assistant_message: failed_message,
      rag_result: nil,
      error: nil
    )
    service = Object.new
    service.define_singleton_method(:call) { result }

    captured_arguments = nil
    factory = lambda do |**arguments|
      captured_arguments = arguments
      service
    end

    Chat::RetryAnswer.stub(:new, factory) do
      post retry_workspace_chat_session_chat_message_url(
        @workspace,
        @chat_session,
        failed_message
      )
    end

    assert_equal @workspace,
      captured_arguments[:workspace]
    assert_equal @user,
      captured_arguments[:user]
    assert_equal failed_message,
      captured_arguments[:assistant_message]

    assert_redirected_to workspace_chat_session_url(
      @workspace,
      @chat_session
    )
    assert_equal "Câu trả lời đã được tạo lại.",
      flash[:notice]
  end

  test "does not retry a completed assistant message" do
    message = @chat_session.chat_messages.create!(
      role: :assistant,
      content: "Completed answer"
    )

    post retry_workspace_chat_session_chat_message_url(
      @workspace,
      @chat_session,
      message
    )

    assert_response :forbidden
  end
end
