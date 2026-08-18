module Admin
  class DashboardController < BaseController
    def index
      @total_users = User.count
      @system_admins_count = User.system_admin.count
      @total_workspaces = Workspace.count
      @total_documents = Document.count
      @completed_documents = Document.completed.count
      @total_chunks = DocumentChunk.count
      @total_chat_sessions = ChatSession.count
      @total_chat_messages = ChatMessage.count
      @total_tokens_consumed = ChatMessage.sum(:total_tokens)
      @recent_users = User.order(created_at: :desc).limit(5)
      @recent_documents = Document.order(created_at: :desc).limit(5)
    end
  end
end
