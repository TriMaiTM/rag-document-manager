class ChatMessageSource < ApplicationRecord
  belongs_to :chat_message,
    inverse_of: :chat_message_sources

  belongs_to :document, optional: true
  belongs_to :document_chunk, optional: true

  validates :rank,
    numericality: {
      only_integer: true,
      greater_than: 0
    },
    uniqueness: { scope: :chat_message_id }

  validates :document_title, :content, presence: true

  validates :page_number,
    numericality: {
      only_integer: true,
      greater_than: 0
    }

  validates :cosine_distance,
    numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2
    }
end
