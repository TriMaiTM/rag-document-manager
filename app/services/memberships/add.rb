module Memberships
  class Add
    def initialize(workspace:, email_address:, role:)
      @workspace = workspace
      @email_address = email_address
      @role = role
    end

    def call
      membership = workspace.memberships.new(role: role)
      user = User.find_by(email_address: normalized_email_address)

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

    attr_reader :workspace, :email_address, :role

    def normalized_email_address
      email_address.to_s.strip.downcase
    end
  end
end
