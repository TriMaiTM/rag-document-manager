class NotifyAdminNewUserJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    # 1. Send Telegram Notification to Admin
    TelegramNotifier.notify_new_user(user)

    # 2. Send Admin Mailer
    AdminMailer.with(user: user).new_user_notification.deliver_now
  rescue StandardError => e
    Rails.logger.error("[NotifyAdminNewUserJob] Error notifying admin for user ##{user_id}: #{e.message}")
  end
end
