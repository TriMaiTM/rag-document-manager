class WorkspacesController < ApplicationController
  before_action :set_workspace, only: [ :show, :edit, :update, :destroy ]
  after_action :verify_policy_scoped, only: :index
  after_action :verify_authorized, except: :index

  def index
    workspaces = policy_scope(Workspace)
    recent_session = Current.user
      .chat_sessions
      .where(workspace: workspaces)
      .recent_first
      .first

    if recent_session
      redirect_to workspace_chat_session_path(
        recent_session.workspace,
        recent_session
      )
    elsif @navigation_workspaces.any?
      redirect_to workspace_chat_sessions_path(@navigation_workspaces.first)
    else
      redirect_to new_workspace_path
    end
  end

  def reorder
    authorize Workspace

    requested_ids = Array(params[:workspace_ids]).map(&:to_i)
    memberships = Current.user.memberships.where(workspace_id: requested_ids)
    accessible_ids = Current.user.memberships.pluck(:workspace_id)

    unless requested_ids.uniq.length == requested_ids.length &&
        requested_ids.sort == accessible_ids.sort
      return head :unprocessable_entity
    end

    membership_by_workspace_id = memberships.index_by(&:workspace_id)

    Membership.transaction do
      requested_ids.each_with_index do |workspace_id, position|
        membership_by_workspace_id.fetch(workspace_id).update!(position: position)
      end
    end

    head :no_content
  end

  def show
    authorize @workspace

    @membership = @workspace.membership_for(Current.user)
    @document_count = @workspace.documents.count
    @completed_document_count = @workspace.documents.completed.count
    @member_count = @workspace.memberships.count
    @recent_documents = @workspace.documents.order(created_at: :desc).limit(5)
    @recent_chat_sessions = Current.user
      .chat_sessions
      .where(workspace: @workspace)
      .recent_first
      .limit(5)
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
