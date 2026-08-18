module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_system_admin!

    private

    def ensure_system_admin!
      return if current_user&.system_admin?

      redirect_to root_path, alert: "Bạn không có quyền truy cập trang quản trị hệ thống."
    end
  end
end
