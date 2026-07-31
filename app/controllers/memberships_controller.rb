class MembershipsController < ApplicationController
  before_action :set_workspace
  before_action :set_membership, only: [ :update, :destroy ]
  after_action :verify_authorized

  def index
    authorize membership_context

    @membership = membership_context
    load_memberships
  end

  def create
    attributes = membership_params
    candidate = @workspace.memberships.new(role: attributes[:role])
    authorize candidate

    @email_address = attributes[:email_address]
    @membership = Memberships::Add.new(
      workspace: @workspace,
      email_address: @email_address,
      role: attributes[:role]
    ).call

    if @membership.persisted?
      redirect_to workspace_memberships_path(@workspace),
        notice: "Thành viên đã được thêm vào Workspace."
    else
      load_memberships
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @membership.assign_attributes(role: role_param)
    authorize @membership

    if @membership.save
      redirect_to workspace_memberships_path(@workspace),
        notice: "Vai trò thành viên đã được cập nhật."
    else
      @email_address = nil
      load_memberships
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @membership
    @membership.destroy!

    redirect_to workspace_memberships_path(@workspace),
      notice: "Thành viên đã được xóa khỏi Workspace.",
      status: :see_other
  end

  private

  def set_workspace
    @workspace = policy_scope(Workspace).find(params[:workspace_id])
    Current.workspace = @workspace
  end

  def set_membership
    @membership = @workspace.memberships.find(params[:id])
  end

  def membership_context
    @workspace.memberships.new(role: :member)
  end

  def membership_params
    params.expect(membership: [ :email_address, :role ])
  end

  def role_param
    params.expect(membership: [ :role ])[:role]
  end

  def load_memberships
    @memberships = @workspace
      .memberships
      .includes(:user)
      .order(:created_at, :id)
  end
end
