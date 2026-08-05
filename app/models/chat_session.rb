class ChatSession < ApplicationRecord
  MAX_TITLE_LENGTH = 120

  belongs_to :workspace
  belongs_to :user

  has_many :chat_messages,
    -> { order(:created_at, :id) },
    dependent: :destroy,
    inverse_of: :chat_session

  validates :title,
    presence: true,
    length: { maximum: MAX_TITLE_LENGTH }
  
  scope :recent_first, -> { order(updated_at: :desc, id: :desc) }
end
