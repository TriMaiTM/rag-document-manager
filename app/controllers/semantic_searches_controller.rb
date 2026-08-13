class SemanticSearchesController < ApplicationController
  before_action :set_workspace
  rate_limit_ai_requests only: :show,
    if: -> { params.key?(:query) }
  after_action :verify_authorized

  def show
    authorize @workspace, :show?

    redirect_to workspace_chat_sessions_path(@workspace),
      notice: "Tìm kiếm ngữ nghĩa đã được tích hợp vào cuộc trò chuyện."
  end

  private

  def set_workspace
    @workspace = policy_scope(Workspace).find(params[:workspace_id])
    Current.workspace = @workspace
  end
end
