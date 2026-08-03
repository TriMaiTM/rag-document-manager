class ChatMessage < ApplicationRecord
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

  validates :content, presence: true

  validates :prompt_tokens,
    :candidate_tokens,
    :total_tokens,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0
    }

  validate :user_message_has_no_generation_metadata

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
end
