class WorkspaceMailer < ApplicationMailer
  def welcome_member
    @membership = params[:membership]
    @user = @membership.user
    @workspace = @membership.workspace

    mail(
      to: @user.email,
      subject: "[Codexys] Bạn đã được thêm vào workspace #{@workspace.name}"
    )
  end

  def member_joined
    @membership = params[:membership]
    @user = @membership.user
    @workspace = @membership.workspace

    # Notify existing workspace owners/admins (except the newly joined member)
    recipient_emails = @workspace.memberships
      .where(role: [:owner, :admin])
      .where.not(user_id: @user.id)
      .joins(:user)
      .pluck("users.email")
      .uniq

    return if recipient_emails.empty?

    mail(
      to: recipient_emails,
      subject: "[Codexys] Thành viên #{@user.display_name} vừa tham gia workspace #{@workspace.name}"
    )
  end
end
