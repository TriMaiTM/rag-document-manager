require "net/http"
require "uri"

class TelegramNotifier
  def self.notify(message)
    token = ENV["TELEGRAM_BOT_TOKEN"] || Rails.application.credentials.dig(:telegram, :bot_token)
    chat_id = ENV["TELEGRAM_CHAT_ID"] || Rails.application.credentials.dig(:telegram, :chat_id)

    return unless token.present? && chat_id.present?

    uri = URI("https://api.telegram.org/bot#{token}/sendMessage")
    params = {
      chat_id: chat_id,
      text: message,
      parse_mode: "HTML"
    }

    response = Net::HTTP.post_form(uri, params)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("[TelegramNotifier] HTTP #{response.code}: #{response.body}")
    end
    response
  rescue StandardError => e
    Rails.logger.error("[TelegramNotifier] Failed to send notification: #{e.message}")
    nil
  end

  def self.notify_new_user(user)
    msg = <<~TEXT
      <b>Codexys- Người dùng mới đăng ký</b>
      ━━━━━━━━━━━━━━━━━━━━
      <b>Email:</b> <code>#{user.email}</code>
      <b>Tên hiển thị:</b> #{user.display_name}
      <b>Thời gian:</b> #{Time.current.strftime("%H:%M:%S %d/%m/%Y")}
    TEXT

    notify(msg.strip)
  end
end
