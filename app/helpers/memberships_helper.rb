module MembershipsHelper
  ROLE_LABELS = {
    "owner" => "Owner",
    "admin" => "Admin",
    "member" => "Member"
  }.freeze

  def membership_role_label(membership)
    ROLE_LABELS.fetch(membership.role, membership.role)
  end

  def manageable_role_options
    [
      [ "Admin", "admin" ],
      [ "Member", "member" ]
    ]
  end
end
