class AdminMailer < ApplicationMailer
  def new_user_notification
    @user = params[:user]
    admin_emails = User.where(system_role: :system_admin).pluck(:email)
    admin_emails << ENV["ADMIN_EMAIL"] if ENV["ADMIN_EMAIL"].present?
    admin_emails = admin_emails.compact.uniq

    return if admin_emails.empty?

    mail(to: admin_emails, subject: "[Codexys Admin] Có người dùng mới đăng ký: #{@user.email}")
  end
end
