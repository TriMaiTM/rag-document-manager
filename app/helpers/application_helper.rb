module ApplicationHelper
  def app_shell?
    user_signed_in? && (!devise_controller? || account_settings_page?)
  end

  def account_settings_page?
    devise_controller? && controller_name == "registrations" &&
      action_name.in?([ "edit", "update" ])
  end

  def ui_icon(name, class_name: nil)
    content_tag(
      "ion-icon",
      nil,
      name: name,
      class: [ "ui-icon", class_name ].compact,
      aria: { hidden: true }
    )
  end

  def body_class
    classes = [
      user_signed_in? ? "app-body" : "public-body",
      "page-#{controller_name}",
      "action-#{action_name}"
    ]

    classes.join(" ")
  end

  def active_workspace?(workspace)
    active_workspace = if defined?(@workspace) && @workspace.present?
      @workspace
    else
      @navigation_active_workspace
    end

    active_workspace == workspace
  end

  def workspace_initials(workspace)
    workspace.name
      .split
      .first(2)
      .filter_map { |word| word.first&.upcase }
      .join
  end

  def sidebar_chat_sessions(workspace)
    return ChatSession.none unless active_workspace?(workspace)

    @sidebar_chat_sessions ||= Current.user
      .chat_sessions
      .where(workspace: workspace)
      .recent_first
      .limit(5)
  end

  def current_user_initial
    return "" unless Current.user

    Current.user.display_name.first.upcase
  end

  def safe_return_to(url)
    return nil if url.blank?

    str = url.to_s
    return str if str.start_with?("/") && !str.start_with?("//") && !str.include?(":")

    nil
  end
end
