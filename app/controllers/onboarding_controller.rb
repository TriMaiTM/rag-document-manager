class OnboardingController < ApplicationController
  before_action :authenticate_user!
  layout "onboarding"

  def show
    if current_user.workspaces.any?
      redirect_to workspaces_path
      return
    end

    @workspace = Workspace.new
  end

  def update
    ActiveRecord::Base.transaction do
      if onboarding_params[:name].present?
        current_user.update!(name: onboarding_params[:name].strip)
      end

      workspace_name = onboarding_params[:workspace_name].presence || "Workspace đầu tiên"
      workspace = Workspace.create!(
        name: workspace_name.strip,
        description: onboarding_params[:workspace_description]
      )

      workspace.memberships.create!(
        user: current_user,
        role: :owner
      )

      redirect_to workspace_chat_sessions_path(workspace),
        notice: "Chào mừng #{current_user.display_name}! Workspace '#{workspace.name}' đã sẵn sàng."
    end
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = "Có lỗi xảy ra: #{error.message}"
    render :show, status: :unprocessable_entity
  end

  private

  def onboarding_params
    params.require(:onboarding).permit(:name, :workspace_name, :workspace_description)
  end
end
