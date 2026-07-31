class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :restrict_with_error
  has_many :workspaces, through: :memberships
  has_many :uploaded_documents,
    class_name: "Document",
    foreign_key: :uploaded_by_id,
    inverse_of: :uploaded_by,
    dependent: :restrict_with_error

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address,
    presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password,
    length: { minimum: 8 },
    if: -> { password.present? }

  validates :password_confirmation,
    presence: true,
    if: -> { password.present? }
end
