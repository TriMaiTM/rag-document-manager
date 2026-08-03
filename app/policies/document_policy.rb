class DocumentPolicy < ApplicationPolicy
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  def download?
    show?
  end

  def retry_processing?
    membership&.owner? || membership&.admin?
  end

  def create?
    membership&.owner? || membership&.admin?
  end
  alias_method :new?, :create?

  def destroy?
    membership&.owner? || membership&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope
        .joins(workspace: :memberships)
        .where(memberships: { user_id: user.id })
        .distinct
    end
  end

  private

  def membership
    @membership ||= record.workspace.membership_for(user)
  end
end
