class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :workspace

  before_validation :assign_sidebar_position, on: :create

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

  after_create_commit :send_membership_notifications

  private

  def send_membership_notifications
    # Send welcome email to the newly joined user
    WorkspaceMailer.with(membership: self).welcome_member.deliver_later

    # Send join notification to other workspace admins/owners (unless owner initializing workspace)
    WorkspaceMailer.with(membership: self).member_joined.deliver_later unless owner?
  end

  def assign_sidebar_position
    return unless user

    last_position = user.memberships.maximum(:position)
    self.position = last_position ? last_position + 1 : 0
  end

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
