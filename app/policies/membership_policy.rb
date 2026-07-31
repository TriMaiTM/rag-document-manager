class MembershipPolicy < ApplicationPolicy
  def index?
    manages_members?
  end

  def create?
    manages_members? && manageable_role?
  end

  def update?
    manages_members? && !owner_record? && manageable_role?
  end

  def destroy?
    manages_members? && !owner_record?
  end

  private

  def actor_membership
    @actor_membership ||= record.workspace.membership_for(user)
  end

  def manages_members?
    actor_membership&.owner? || actor_membership&.admin?
  end

  def manageable_role?
    record.admin? || record.member?
  end

  def owner_record?
    record.persisted? && record.role_in_database == "owner"
  end
end
