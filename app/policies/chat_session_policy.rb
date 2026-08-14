class ChatSessionPolicy < ApplicationPolicy
  def index?
    membership.present?
  end

  def show?
    membership.present? && owned_by_user?
  end

  def update?
    show?
  end

  def update_title?
    update?
  end

  def create?
    membership.present? && owned_by_user?
  end

  def ask?
    show?
  end

  def destroy?
    show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope
        .joins(workspace: :memberships)
        .where(
          user_id: user.id,
          memberships: { user_id: user.id }
        )
        .distinct
    end
  end

  private

  def membership
    @membership ||= record.workspace.membership_for(user)
  end

  def owned_by_user?
    record.user_id == user.id
  end
end
