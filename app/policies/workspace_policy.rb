class WorkspacePolicy < ApplicationPolicy
  def show?
    membership.present?
  end

  def create?
    user.present?
  end
  alias_method :new?, :create?

  def reorder?
    user.present?
  end

  def update?
    membership&.owner? || membership&.admin?
  end
  alias_method :edit?, :update?

  def destroy?
    membership&.owner?
  end

  def manage_members?
    membership&.owner? || membership&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope
        .joins(:memberships)
        .where(memberships: { user_id: user.id })
        .distinct
    end
  end

  private

  def membership
    @membership ||= record.membership_for(user)
  end
end
