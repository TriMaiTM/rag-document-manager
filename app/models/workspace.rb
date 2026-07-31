class Workspace < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :documents, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :description, length: { maximum: 1_000 }, allow_blank: true

  def membership_for(user)
    memberships.find_by(user: user)
  end
end
