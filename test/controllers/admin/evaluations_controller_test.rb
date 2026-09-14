require "test_helper"

module Admin
  class EvaluationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @admin = users(:two)
      @admin.update!(system_role: :system_admin)

      # Ensure a sample report exists for testing download
      @sample_filename = "rag_evaluation_20260915010606.json"
      @reports_dir = Rails.root.join("storage", "evaluations")
      FileUtils.mkdir_p(@reports_dir)
      File.write(@reports_dir.join(@sample_filename), '{"workspace_id":1,"hit_rate":0.917,"limit":5}')
    end

    test "redirects normal user from admin evaluations" do
      sign_in @user
      get admin_evaluations_url

      assert_redirected_to root_url
      assert_equal "Bạn không có quyền truy cập trang quản trị hệ thống.", flash[:alert]
    end

    test "allows system admin to access admin evaluations" do
      sign_in @admin
      get admin_evaluations_url

      assert_response :success
      assert_select "h1", /Đánh giá Benchmark/
    end

    test "allows system admin to download report as json" do
      sign_in @admin
      clean_id = @sample_filename.sub(/\.json\z/, "")
      get admin_evaluation_url(id: clean_id, format: :json)

      assert_response :success
      assert_equal "application/json", response.media_type
      assert_includes response.body, "hit_rate"
    end

    test "handles download with full filename ending in dot json" do
      sign_in @admin
      get "/admin/evaluations/#{@sample_filename}"

      assert_response :success
      assert_equal "application/json", response.media_type
    end
  end
end
