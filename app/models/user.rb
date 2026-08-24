class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable, :confirmable

  has_one_attached :avatar

  enum :system_role, {
    user: "user",
    system_admin: "system_admin"
  }, default: :user, validate: true

  has_many :memberships, dependent: :restrict_with_error
  has_many :workspaces, through: :memberships
  has_many :chat_sessions, dependent: :restrict_with_error
  has_many :uploaded_documents,
    class_name: "Document",
    foreign_key: :uploaded_by_id,
    inverse_of: :uploaded_by,
    dependent: :restrict_with_error

  validates :name, length: { maximum: 100 }, allow_blank: true

  after_commit :notify_admin_on_registration, on: :create

  def display_name
    name.presence || email.split("@").first
  end

  # Send Devise emails (confirmations, password resets) asynchronously via ActiveJob
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  private

  def notify_admin_on_registration
    NotifyAdminNewUserJob.perform_later(id)
  end
end
