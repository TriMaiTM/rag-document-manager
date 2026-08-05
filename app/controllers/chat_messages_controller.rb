class ChatMessagesController < ApplicationController
  before_action :set_workspace
  before_action :set_chat_session
  before_action :set_chat_message, only: :retry
  rate_limit_ai_requests only: [ :create, :retry ]

  after_action :verify_authorized

  def retry
    authorize @chat_message, :retry?

    result = Chat::RetryAnswer.new(
      workspace: @workspace,
      user: Current.user,
      assistant_message: @chat_message
    ).call

    if result.failed?
      log_chat_error(result.error)
      redirect_with_error(Chat::Ask::FAILURE_ANSWER)
    else
      redirect_to workspace_chat_session_path(
        @workspace,
        @chat_session
      ), notice: "Câu trả lời đã được tạo lại."
    end
  rescue Chat::RetryAnswer::InvalidMessageError,
    ChatMessage::InvalidStatusTransitionError
    redirect_with_error(
      "Câu trả lời này đang được xử lý hoặc không thể thử lại."
    )
  end

  def create
    authorize @chat_session, :ask?

    result = Chat::Ask.new(
      workspace: @workspace,
      user: Current.user,
      question: params[:question].to_s,
      chat_session: @chat_session
    ).call

    if result.failed?
      log_chat_error(result.error)
      redirect_with_error(Chat::Ask::FAILURE_ANSWER)
    else
      redirect_to workspace_chat_session_path(
        @workspace,
        @chat_session
      ), notice: "Câu trả lời mới đã được lưu."
    end
  rescue SemanticSearch::Search::InvalidQueryError => error
    redirect_with_error(error.message)
  rescue Rag::AnswerQuestion::GenerationError,
    Ai::GeminiClient::Error,
    Ai::GenerateQueryEmbedding::Error,
    Codexys::GeminiConfiguration::MissingApiKeyError => error
    Rails.logger.warn("Chat follow-up failed: #{error.class}: #{error.message}")
    redirect_with_error(
      "Gemini chưa thể trả lời lúc này. Vui lòng thử lại."
    )
  end

  private

  def set_chat_message
    @chat_message = policy_scope(ChatMessage)
      .where(chat_session: @chat_session)
      .find(params[:id])
  end

  def set_workspace
    @workspace = policy_scope(Workspace).find(params[:workspace_id])
    Current.workspace = @workspace
  end

  def set_chat_session
    @chat_session = policy_scope(ChatSession)
      .where(workspace: @workspace)
      .find(params[:chat_session_id])
  end

  def redirect_with_error(message)
    redirect_to workspace_chat_session_path(
      @workspace,
      @chat_session
    ), alert: message
  end

  def log_chat_error(error)
    original_error = if error.respond_to?(:original_error)
      error.original_error
    else
      error
    end

    Rails.logger.warn(
      "Chat follow-up failed: " \
        "#{original_error.class}: #{original_error.message}"
    )
  end
end
