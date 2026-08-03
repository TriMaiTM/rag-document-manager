class ChatMessagesController < ApplicationController
  before_action :set_workspace
  before_action :set_chat_session

  after_action :verify_authorized

  def create
    authorize @chat_session, :ask?

    Chat::Ask.new(
      workspace: @workspace,
      user: Current.user,
      question: params[:question].to_s,
      chat_session: @chat_session
    ).call

    redirect_to workspace_chat_session_path(
      @workspace,
      @chat_session
    ), notice: "Câu trả lời mới đã được lưu."
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
end
