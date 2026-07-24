class WorkspacesController < ApplicationController
  before_action :set_workspace, only: [ :show, :edit, :update, :destroy ]
  after_action :verify_policy_scoped, only: :index
  after_action :verify_authorized, except: :index

  def index
    @workspaces = policy_scope(Workspace).order(created_at: :desc)
  end

  def show
    authorize @workspace
  end

  def new
    @workspace = Workspace.new
    authorize @workspace
  end

  def create
    @workspace = Workspace.new(workspace_params)
    authorize @workspace

    Workspaces::Create.new(
      user: Current.user,
      workspace: @workspace
    ).call

    if @workspace.persisted?
      redirect_to @workspace,
        notice: "Workspace đã được tạo thành công."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @workspace
  end

  def update
    authorize @workspace

    if @workspace.update(workspace_params)
      redirect_to @workspace,
        notice: "Workspace đã được cập nhật thành công."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @workspace
    @workspace.destroy!

    redirect_to workspaces_path,
      notice: "Workspace đã được xóa thành công.",
      status: :see_other
  end

  private

  def set_workspace
    @workspace = policy_scope(Workspace).find(params[:id])
    Current.workspace = @workspace
  end

  def workspace_params
    params.expect(workspace: [ :name, :description ])
  end
end
