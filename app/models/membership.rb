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

  validate :owner_role_cannot_change,
    on: :update

  before_destroy :keep_workspace_owner

  private

  def owner_role_cannot_change
    return unless role_in_database == "owner" && will_save_change_to_role?

    errors.add(:role, "cannot be changed for the workspace owner")
  end

  def keep_workspace_owner
    return unless owner?
    return if destroyed_by_association

    errors.add(:base, "The workspace owner cannot be removed")
    throw :abort
  end
end
