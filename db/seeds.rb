Workspace.find_or_create_by!(name: "Codexys Development") do |workspace|
  workspace.description =
    "Không gian quản lý tài liệu phát triển dự án Codexys."
end

Workspace.find_or_create_by!(name: "Software Engineering") do |workspace|
  workspace.description =
    "Không gian lưu trữ tài liệu kỹ thuật và quy trình phát triển."
end
