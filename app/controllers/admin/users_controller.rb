module Admin
  class UsersController < BaseController
    def index
      @users = User.order(created_at: :desc)
    end

    def show
      @user = User.find(params[:id])
      @workspaces = @user.workspaces.order(created_at: :desc)
      @uploaded_documents = @user.uploaded_documents.order(created_at: :desc)
    end

    def update
      @user = User.find(params[:id])

      if @user == current_user && user_params[:system_role] == "user"
        redirect_back fallback_location: admin_users_path, alert: "Bạn không thể tự hạ quyền System Admin của chính mình."
        return
      end

      if @user.update(user_params)
        redirect_back fallback_location: admin_users_path, notice: "Cập nhật quyền tài khoản #{@user.email} thành công."
      else
        redirect_back fallback_location: admin_users_path, alert: "Không thể cập nhật quyền tài khoản."
      end
    end

    private

    def user_params
      params.require(:user).permit(:system_role)
    end
  end
end
