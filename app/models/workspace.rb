class Workspace < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_one :owner_membership, -> { where(role: :owner) }, class_name: "Membership"
  has_one :owner, through: :owner_membership, source: :user
  has_many :documents, dependent: :destroy
  has_many :chat_sessions, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :description, length: { maximum: 1_000 }, allow_blank: true

  def membership_for(user)
    memberships.find_by(user: user)
  end
end
