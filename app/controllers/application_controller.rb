class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :set_current_user
  before_action :set_navigation_workspaces, if: :user_signed_in?

  rescue_from Pundit::NotAuthorizedError,
    with: :render_forbidden

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  def after_sign_in_path_for(_resource)
    workspaces_path
  end

  def after_sign_up_path_for(_resource)
    workspaces_path
  end

  def self.rate_limit_ai_requests(**options)
    rate_limit to: Ai::RequestRateLimit::BURST_LIMIT,
      within: Ai::RequestRateLimit::BURST_WINDOW,
      by: :ai_rate_limit_identity,
      with: -> { render_ai_rate_limited(retry_after: 1.minute) },
      store: Ai::RequestRateLimit.store,
      name: "burst",
      scope: Ai::RequestRateLimit::SCOPE,
      **options

    rate_limit to: Ai::RequestRateLimit::HOURLY_LIMIT,
      within: Ai::RequestRateLimit::HOURLY_WINDOW,
      by: :ai_rate_limit_identity,
      with: -> { render_ai_rate_limited(retry_after: 1.hour) },
      store: Ai::RequestRateLimit.store,
      name: "hourly",
      scope: Ai::RequestRateLimit::SCOPE,
      **options
  end

  private

  def pundit_user
    current_user
  end

  def ai_rate_limit_identity
    "user:#{Current.user.id}"
  end

  def render_ai_rate_limited(retry_after:)
    response.set_header("Retry-After", retry_after.to_i.to_s)

    render "errors/ai_rate_limited",
      status: :too_many_requests
  end

  def set_current_user
    Current.user = current_user
  end

  def set_navigation_workspaces
    @navigation_workspaces = current_user
      .memberships
      .includes(:workspace)
      .order(:position, :created_at)
      .map(&:workspace)

    recent_session = current_user
      .chat_sessions
      .where(workspace_id: @navigation_workspaces.map(&:id))
      .includes(:workspace)
      .recent_first
      .first

    @navigation_active_workspace = recent_session&.workspace ||
      @navigation_workspaces.first
  end

  def render_forbidden
    render plain: "Bạn không có quyền thực hiện hành động này.",
      status: :forbidden
  end
end
