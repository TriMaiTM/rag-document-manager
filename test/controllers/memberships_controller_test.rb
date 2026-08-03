require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @owner = memberships(:one_owner)
    @admin = memberships(:one_admin)
    @member = memberships(:one_member)

    sign_in_as users(:one)
  end

  test "requires authentication" do
    sign_out

    get workspace_memberships_url(@workspace)

    assert_redirected_to new_user_session_url
  end

  test "owner can view member management" do
    get workspace_memberships_url(@workspace)

    assert_response :success
    assert_select "h1", "Thành viên Workspace"
    assert_select "td", users(:one).email
    assert_select "td", users(:two).email
    assert_select "td", users(:three).email
  end

  test "admin can view member management" do
    sign_out
    sign_in_as users(:three)

    get workspace_memberships_url(@workspace)

    assert_response :success
  end

  test "member cannot view member management" do
    sign_out
    sign_in_as users(:two)

    get workspace_memberships_url(@workspace)

    assert_response :forbidden
  end

  test "outsider receives not found" do
    sign_out
    sign_in_as users(:four)

    get workspace_memberships_url(@workspace)

    assert_response :not_found
  end

  test "owner adds an existing user by email" do
    assert_difference("Membership.count", 1) do
      post workspace_memberships_url(@workspace), params: {
        membership: {
          email: " FOUR@EXAMPLE.COM ",
          role: "member"
        }
      }
    end

    membership = @workspace.memberships.find_by!(user: users(:four))
    assert membership.member?
    assert_redirected_to workspace_memberships_url(@workspace)
  end

  test "does not add an unknown email" do
    assert_no_difference("Membership.count") do
      post workspace_memberships_url(@workspace), params: {
        membership: {
          email: "missing@example.com",
          role: "member"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']"
  end

  test "does not add an existing membership twice" do
    assert_no_difference("Membership.count") do
      post workspace_memberships_url(@workspace), params: {
        membership: {
          email: users(:two).email,
          role: "admin"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']"
  end

  test "cannot create another owner through membership params" do
    assert_no_difference("Membership.count") do
      post workspace_memberships_url(@workspace), params: {
        membership: {
          email: users(:four).email,
          role: "owner"
        }
      }
    end

    assert_response :forbidden
  end

  test "owner updates a member role" do
    patch workspace_membership_url(@workspace, @member), params: {
      membership: { role: "admin" }
    }

    assert_redirected_to workspace_memberships_url(@workspace)
    assert @member.reload.admin?
  end

  test "admin updates a member role" do
    sign_out
    sign_in_as users(:three)

    patch workspace_membership_url(@workspace, @member), params: {
      membership: { role: "admin" }
    }

    assert_redirected_to workspace_memberships_url(@workspace)
    assert @member.reload.admin?
  end

  test "member cannot update another membership" do
    sign_out
    sign_in_as users(:two)

    assert_no_changes -> { @admin.reload.role } do
      patch workspace_membership_url(@workspace, @admin), params: {
        membership: { role: "member" }
      }
    end

    assert_response :forbidden
  end

  test "owner cannot change the owner membership" do
    assert_no_changes -> { @owner.reload.role } do
      patch workspace_membership_url(@workspace, @owner), params: {
        membership: { role: "member" }
      }
    end

    assert_response :forbidden
  end

  test "admin cannot remove owner" do
    sign_out
    sign_in_as users(:three)

    assert_no_difference("Membership.count") do
      delete workspace_membership_url(@workspace, @owner)
    end

    assert_response :forbidden
  end

  test "owner removes a member" do
    assert_difference("Membership.count", -1) do
      delete workspace_membership_url(@workspace, @member)
    end

    assert_redirected_to workspace_memberships_url(@workspace)
  end

  test "cannot access a membership through another workspace" do
    assert_no_difference("Membership.count") do
      delete workspace_membership_url(
        @workspace,
        memberships(:two_owner)
      )
    end

    assert_response :not_found
  end
end
