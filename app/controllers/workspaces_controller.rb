class WorkspacesController < ApplicationController
  before_action :set_workspace, only: [ :show, :edit, :update, :destroy ]

  def index
    @workspaces = Workspace.order(created_at: :desc)
  end

  def show
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

  def edit
  end

  def update
    if @workspace.update(workspace_params)
      redirect_to @workspace,
        notice: "Workspace đã được cập nhật thành công."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @workspace.destroy!

    redirect_to workspaces_path,
      notice: "Workspace đã được xóa thành công.",
      status: :see_other
  end

  private

  def set_workspace
    @workspace = Workspace.find(params[:id])
  end

  def workspace_params
    params.expect(workspace: [ :name, :description ])
  end
end
