class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :set_current_user

  rescue_from Pundit::NotAuthorizedError,
    with: :render_forbidden

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def pundit_user
    current_user
  end

  def set_current_user
    Current.user = current_user
  end

  def render_forbidden
    render plain: "Bạn không có quyền thực hiện hành động này.",
      status: :forbidden
  end
end
