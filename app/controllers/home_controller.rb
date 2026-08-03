class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @application_name = "Codexys"
    @description = "Nền tảng quản lý và hỏi đáp tài liệu bằng RAG"
  end
end
