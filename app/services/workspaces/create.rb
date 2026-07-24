module Workspaces
  class Create
    def initialize(user:, workspace:)
      @user = user
      @workspace = workspace
    end

    def call
      return workspace unless workspace.valid?

      Workspace.transaction do
        workspace.save!
        workspace.memberships.create!(user: user, role: :owner)
      end

      workspace
    end

    private

    attr_reader :user, :workspace
  end
end
