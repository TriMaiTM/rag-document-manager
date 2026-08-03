module Memberships
  class Add
    def initialize(workspace:, email:, role:)
      @workspace = workspace
      @email = email
      @role = role
    end

    def call
      membership = workspace.memberships.new(role: role)
      user = User.find_by(email: normalized_email)

      unless user
        membership.errors.add(
          :user,
          "was not found for that email address"
        )
        return membership
      end

      membership.user = user
      membership.save
      membership
    end

    private

    attr_reader :workspace, :email, :role

    def normalized_email
      email.to_s.strip.downcase
    end
  end
end
