class WorkspacesController < ApplicationController
    def index
        @workspaces = Workspace.order(created_at: :desc)
    end

    def show
        @workspace = Workspace.find(params[:id])
    end
end
