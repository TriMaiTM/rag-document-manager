class SemanticSearchesController < ApplicationController
  before_action :set_workspace
  rate_limit_ai_requests only: :show,
    if: -> { params.key?(:query) }
  after_action :verify_authorized

  def show
    authorize @workspace, :show?

    @query = params[:query].to_s
    @searched = params.key?(:query)
    @answer = nil
    @answer_error = nil
    @chunks = []

    search if @searched
  end

  private

  def set_workspace
    @workspace = policy_scope(Workspace).find(params[:workspace_id])
    Current.workspace = @workspace
  end

  def search
    result = Rag::AnswerQuestion.new(
      workspace: @workspace,
      question: @query
    ).call

    @query = result.query
    @answer = result.answer
    @chunks = result.chunks
  rescue Rag::AnswerQuestion::GenerationError => error
    @query = error.query
    @chunks = error.chunks
    @answer_error =
      "Đã tìm thấy nguồn phù hợp nhưng Gemini chưa thể tạo câu trả lời. " \
        "Vui lòng thử lại."

    Rails.logger.warn(
      "RAG generation failed: " \
        "#{error.original_error.class}: #{error.original_error.message}"
    )
  rescue SemanticSearch::Search::InvalidQueryError => error
    @search_error = error.message
  rescue Ai::GeminiClient::Error,
    Ai::GenerateQueryEmbedding::Error,
    Ai::GenerateGroundedAnswer::Error,
    Codexys::GeminiConfiguration::MissingApiKeyError => error
    Rails.logger.warn(
      "RAG answer failed: #{error.class}: #{error.message}"
    )
    @search_error =
      "Không thể trả lời câu hỏi lúc này. Vui lòng thử lại."
  end
end
