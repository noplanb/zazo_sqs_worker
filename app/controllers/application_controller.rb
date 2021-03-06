class ApplicationController < ActionController::API
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # protect_from_forgery with: :exception

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def not_found
    head :not_found
  end

  def render_errors(errors)
    render json: { errors: errors }, status: :unprocessable_entity
  end
end
