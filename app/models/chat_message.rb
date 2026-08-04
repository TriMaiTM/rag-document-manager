class ChatMessage < ApplicationRecord
  ERROR_CODE_MAX_LENGTH = 100

  belongs_to :chat_session,
    touch: true,
    inverse_of: :chat_messages

  has_many :chat_message_sources,
    -> { order(:rank) },
    dependent: :destroy,
    inverse_of: :chat_message

  enum :role, {
    user: "user",
    assistant: "assistant"
  }, validate: true

  enum :status, {
    completed: "completed",
    failed: "failed"
  }, validate: true

  validates :content, presence: true
  validates :error_code,
    length: { maximum: ERROR_CODE_MAX_LENGTH },
    allow_nil: true

  validates :prompt_tokens,
    :candidate_tokens,
    :total_tokens,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0
    }

  validate :user_message_has_no_generation_metadata
  validate :failure_metadata_is_consistent
  validate :user_message_is_completed

  private

  def user_message_has_no_generation_metadata
    return unless user?

    metadata_present =
      model.present? ||
      prompt_tokens.positive? ||
      candidate_tokens.positive? ||
      total_tokens.positive?

    return unless metadata_present

    errors.add(
      :base,
      "Tin nhắn người dùng không được có metadata sinh nội dung"
    )
  end

  def failure_metadata_is_consistent
    if failed? && error_code.blank?
      errors.add(:error_code, "phải có khi tin nhắn thất bại")
    elsif completed? && error_code.present?
      errors.add(:error_code, "phải để trống khi tin nhắn hoàn thành")
    end
  end

  def user_message_is_completed
    return unless user? && !completed?

    errors.add(:status, "của câu hỏi người dùng phải là completed")
  end
end
