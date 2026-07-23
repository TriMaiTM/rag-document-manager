class WorkspacesController < ApplicationController
    def index
        @workspaces = Workspace.order(created_at: :desc)
    end

    def show
        @workspace = Workspace.find(params[:id])
    end

    def new
        @workspace = Workspace.new
    end

    def create 
        @workspace = Workspace.new(workspace_params)
        if @workspace.save
            redirect_to @workspace,
                notice: "Workspace đã được tạo thành công."
        else
            render :new, status: :unprocessable_entity
        end
    end

    private

    def workspace_params
        params.expect(workspace: [:name, :description])
    end
end
