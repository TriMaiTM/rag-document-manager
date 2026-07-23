class HomeController < ApplicationController
  def index
    @application_name = "Codexys"
    @description = "Nền tảng quản lý và hỏi đáp tài liệu bằng RAG"
  end
end
