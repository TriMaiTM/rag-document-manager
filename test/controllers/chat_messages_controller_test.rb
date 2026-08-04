require "test_helper"

class ChatMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
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
end
