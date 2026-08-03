module SessionTestHelper
  def sign_in_as(user)
    sign_in user
  end

  def sign_out
    super(:user)
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include Devise::Test::IntegrationHelpers
  include SessionTestHelper
end
