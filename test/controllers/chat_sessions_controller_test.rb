require "test_helper"

class ChatSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Ai::RequestRateLimit.store.clear

    @workspace = workspaces(:one)
    @user = users(:one)
    @chat_session = ChatSession.create!(
      workspace: @workspace,
      user: @user,
      title: "Rails security"
    )
    @other_session = ChatSession.create!(
      workspace: @workspace,
      user: users(:two),
      title: "Member private chat"
    )

    sign_in_as @user
  end

  test "requires authentication" do
    sign_out

    get workspace_chat_sessions_url(@workspace)

    assert_redirected_to new_user_session_url
  end

  test "lists only the current user's sessions" do
    get workspace_chat_sessions_url(@workspace)

    assert_response :success
    assert_select "h1", "Hỏi đáp tài liệu"
    assert_select "form[action=?]",
      workspace_chat_sessions_path(@workspace)
    assert_select "a", @chat_session.title
    assert_select "a", text: @other_session.title, count: 0
  end

  test "shows a saved conversation and source snapshot" do
    @chat_session.chat_messages.create!(
      role: :user,
      content: "What is CSRF?"
    )
    assistant = @chat_session.chat_messages.create!(
      role: :assistant,
      content: "CSRF is a request forgery attack [1].",
      model: "gemini-test",
      prompt_tokens: 10,
      candidate_tokens: 5,
      total_tokens: 15
    )
    assistant.chat_message_sources.create!(
      rank: 1,
      document_title: "Security Guide",
      page_number: 3,
      content: "CSRF protection content.",
      cosine_distance: 0.2
    )

    get workspace_chat_session_url(@workspace, @chat_session)

    assert_response :success
    assert_select "h1", @chat_session.title
    assert_select "h2", "Bạn"
    assert_select "h2", "Codexys"
    assert_select "p", /request forgery attack \[1\]/
    assert_select "h4", /\[1\].*Security Guide/
    assert_select "p", /80,0%|80\.0%/
    assert_select "form[action=?]",
      workspace_chat_session_chat_messages_path(
        @workspace,
        @chat_session
      )
  end

  test "shows a persisted failed answer without technical details" do
    @chat_session.chat_messages.create!(
      role: :user,
      content: "Question that timed out"
    )
    @chat_session.chat_messages.create!(
      role: :assistant,
      status: :failed,
      content: Chat::Ask::FAILURE_ANSWER,
      error_code: "network_error"
    )

    get workspace_chat_session_url(@workspace, @chat_session)

    assert_response :success
    assert_select "[data-message-status='failed'] [role='alert']",
      text: /Gemini chưa thể trả lời/
    assert_select "body", text: /network_error/, count: 0
  end

  test "creates a new session through the chat service" do
    created_session = ChatSession.create!(
      workspace: @workspace,
      user: @user,
      title: "Created by service"
    )
    service = Object.new
    service.define_singleton_method(:call) do
      Chat::Ask::Result.new(
        chat_session: created_session,
        user_message: nil,
        assistant_message: nil,
        rag_result: nil,
        error: nil
      )
    end
    factory = ->(**_arguments) { service }

    Chat::Ask.stub(:new, factory) do
      post workspace_chat_sessions_url(@workspace),
        params: { question: "What is Rails?" }
    end

    assert_redirected_to workspace_chat_session_url(
      @workspace,
      created_session
    )
  end

  test "redirects to the persisted session when Gemini fails" do
    failed_session = ChatSession.create!(
      workspace: @workspace,
      user: @user,
      title: "Persisted failed question"
    )
    error = Ai::GenerateQueryEmbedding::InvalidResponseError.new(
      "Invalid embedding response"
    )
    service = Object.new
    service.define_singleton_method(:call) do
      Chat::Ask::Result.new(
        chat_session: failed_session,
        user_message: nil,
        assistant_message: nil,
        rag_result: nil,
        error: error
      )
    end

    Chat::Ask.stub(:new, ->(**_arguments) { service }) do
      post workspace_chat_sessions_url(@workspace),
        params: { question: "What is Rails?" }
    end

    assert_redirected_to workspace_chat_session_url(
      @workspace,
      failed_session
    )
    assert_equal Chat::Ask::FAILURE_ANSWER, flash[:alert]
  end

  test "rejects a blank question without calling Gemini" do
    assert_no_difference("ChatSession.count") do
      post workspace_chat_sessions_url(@workspace),
        params: { question: " " }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']", /ít nhất 2 ký tự/
  end

  test "rate limits sustained AI requests for the current user" do
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

    travel_to Time.current do
      Chat::Ask.stub(:new, ->(**_arguments) { service }) do
        4.times do
          Ai::RequestRateLimit::BURST_LIMIT.times do
            post workspace_chat_sessions_url(@workspace),
              params: { question: "Rate limited question" }

            assert_response :redirect
          end

          travel 61.seconds
        end

        post workspace_chat_sessions_url(@workspace),
          params: { question: "One request too many" }
      end
    end

    assert_response :too_many_requests
    assert_equal Ai::RequestRateLimit::HOURLY_LIMIT, calls
    assert_equal "3600", response.headers["Retry-After"]
    assert_select "h1", "Bạn đang gửi câu hỏi quá nhanh"
  end

  test "cannot view another member's session" do
    get workspace_chat_session_url(@workspace, @other_session)

    assert_response :not_found
  end

  test "destroys an owned session" do
    assert_difference("ChatSession.count", -1) do
      delete workspace_chat_session_url(@workspace, @chat_session)
    end

    assert_redirected_to workspace_chat_sessions_url(@workspace)
  end
end
