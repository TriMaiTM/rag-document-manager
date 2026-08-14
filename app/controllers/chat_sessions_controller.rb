class ChatSessionsController < ApplicationController
  before_action :set_workspace
  before_action :set_chat_session, only: [ :show, :update, :destroy ]
  rate_limit_ai_requests only: :create

  after_action :verify_authorized

  def index
    prepare_index
    authorize @chat_session_context
  end

  def show
    authorize @chat_session
    prepare_show
  end

  def update
    authorize @chat_session
    if @chat_session.update(chat_session_params)
      respond_to do |format|
        format.html do
          redirect_to workspace_chat_session_path(@workspace, @chat_session),
            notice: "Tiêu đề cuộc trò chuyện đã được cập nhật."
        end
        format.json { render json: { status: "ok", title: @chat_session.title } }
      end
    else
      respond_to do |format|
        format.html do
          redirect_to workspace_chat_session_path(@workspace, @chat_session),
            alert: "Không thể cập nhật tiêu đề."
        end
        format.json { render json: { error: "Không thể cập nhật tiêu đề." }, status: :unprocessable_entity }
      end
    end
  end

  def create
    candidate = chat_session_context
    authorize candidate

    result = Chat::Ask.new(
      workspace: @workspace,
      user: Current.user,
      question: question
    ).call

    if result.failed?
      log_chat_error(result.error)
      redirect_to workspace_chat_session_path(
        @workspace,
        result.chat_session
      ), alert: Chat::Ask::FAILURE_ANSWER
    else
      redirect_to workspace_chat_session_path(
        @workspace,
        result.chat_session
      ), notice: "Câu hỏi đã được trả lời và lưu vào lịch sử."
    end
  rescue SemanticSearch::Search::InvalidQueryError => error
    render_index_error(error.message, :unprocessable_entity)
  rescue Rag::AnswerQuestion::GenerationError,
    Ai::GeminiClient::Error,
    Ai::GenerateQueryEmbedding::Error,
    Codexys::GeminiConfiguration::MissingApiKeyError => error
    log_chat_error(error)
    render_index_error(
      "Gemini chưa thể trả lời lúc này. Vui lòng thử lại.",
      :bad_gateway
    )
  end

  def destroy
    authorize @chat_session
    @chat_session.destroy!

    redirect_to workspace_chat_sessions_path(@workspace),
      notice: "Phiên hỏi đáp đã được xóa.",
      status: :see_other
  end

  private

  def set_workspace
    @workspace = policy_scope(Workspace).find(params[:workspace_id])
    Current.workspace = @workspace
  end

  def set_chat_session
    @chat_session = policy_scope(ChatSession)
      .where(workspace: @workspace)
      .find(params[:id])
  end

  def prepare_index
    @chat_session_context = chat_session_context
    @chat_sessions = policy_scope(ChatSession)
      .where(workspace: @workspace)
      .recent_first
    @question ||= ""
  end

  def prepare_show
    @chat_messages = @chat_session
      .chat_messages
      .preload(
        :question_message,
        chat_message_sources: :document
      )
    @question = ""
  end

  def chat_session_context
    @workspace.chat_sessions.new(user: Current.user)
  end

  def question
    params[:question].to_s
  end

  def render_index_error(message, status)
    @question = question
    @chat_error = message
    prepare_index

    render :index, status: status
  end

  def log_chat_error(error)
    original_error = if error.respond_to?(:original_error)
      error.original_error
    else
      error
    end

    Rails.logger.warn(
      "Chat question failed: " \
        "#{original_error.class}: #{original_error.message}"
    )
  end

  def chat_session_params
    params.expect(chat_session: [ :title ])
  end
end
