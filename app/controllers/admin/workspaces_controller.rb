module Admin
  class WorkspacesController < BaseController
    def index
      @workspaces = Workspace.order(created_at: :desc)
    end

    def show
      @workspace = Workspace.find(params[:id])
      @memberships = @workspace.memberships.includes(:user)
      @documents = @workspace.documents.order(created_at: :desc)
    end
  end
end
