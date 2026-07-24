owner = User.order(:created_at, :id).first

if owner
  [
    {
      name: "Codexys Development",
      description: "Không gian quản lý tài liệu phát triển dự án Codexys."
    },
    {
      name: "Software Engineering",
      description: "Không gian lưu trữ tài liệu kỹ thuật và quy trình phát triển."
    }
  ].each do |attributes|
    workspace = Workspace.find_or_initialize_by(name: attributes[:name])
    workspace.description ||= attributes[:description]

    unless workspace.memberships.owner.exists?
      Workspaces::Create.new(
        user: owner,
        workspace: workspace
      ).call
    end
  end
else
  puts "Skipping workspace seeds because no user exists."
end
