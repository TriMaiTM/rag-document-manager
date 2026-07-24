class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :workspace

  enum :role, {
    owner: "owner",
    admin: "admin",
    member: "member"
  }, validate: true

  validates :user_id,
    uniqueness: { scope: :workspace_id }

  validates :role,
    uniqueness: { scope: :workspace_id },
    if: :owner?
end
