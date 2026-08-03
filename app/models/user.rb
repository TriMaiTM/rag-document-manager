class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable

  enum :system_role, {
    user: "user",
    system_admin: "system_admin"
  }, default: :user, validate: true

  has_many :memberships, dependent: :restrict_with_error
  has_many :workspaces, through: :memberships
  has_many :uploaded_documents,
           class_name: "Document",
           foreign_key: :uploaded_by_id,
           inverse_of: :uploaded_by,
           dependent: :restrict_with_error
end
