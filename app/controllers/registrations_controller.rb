class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_authenticated_user, if: :authenticated?

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      start_new_session_for @user

      redirect_to workspaces_path,
        notice: "Tài khoản đã được tạo thành công."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.expect(
      user: [ :email_address, :password, :password_confirmation ]
    )
  end

  def redirect_authenticated_user
    redirect_to root_path, notice: "Bạn đã đăng nhập."
  end
end
