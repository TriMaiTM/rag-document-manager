class ChatMessagePolicy < ApplicationPolicy
    def show?
        session_access?
    end

    def create?
        session_access?
    end

    def retry?
        session_access? && record.retryable?
    end

    class Scope < ApplicationPolicy::Scope
        def resolve
            scope
            .joins(chat_session: { workspace: :memberships })
            .where(
                chat_sessions: { user_id: user.id },
                memberships: { user_id: user.id}
            )
            .distinct
        end
    end

    private

    def session_access?
        chat_session.present? &&
            chat_session.user_id == user.id &&
            chat_session.workspace.membership_for(user).present?
    end

    def chat_session
        record.chat_session
    end
end