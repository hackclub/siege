class SubmitApiController < ApplicationController
  before_action :require_authentication

  def authorize
    begin
      response = HTTP.auth("Bearer #{Rails.application.credentials.dig(:submit, :api_key)}")
                     .headers(content_type: "application/json")
                     .post("https://submit.hackclub.com/api/authorize")

      if response.status.success?
        render json: response.parse
      else
        render json: { error: "Failed to create authorization request" }, status: :bad_request
      end
    rescue => e
      Rails.logger.error "Submit authorization failed: #{e.message}"
      render json: { error: "Failed to create authorization request" }, status: :internal_server_error
    end
  end

  def status
    auth_id = params[:auth_id]

    Rails.logger.info "Submit API status check for auth_id: #{auth_id}"

    if auth_id.blank?
      Rails.logger.error "No auth_id provided to submit API status"
      render json: { error: "No authorization ID provided" }, status: :bad_request
      return
    end

    begin
      api_key = Rails.application.credentials.dig(:submit, :api_key)
      if api_key.blank?
        Rails.logger.error "Submit API key not configured in credentials"
        render json: { error: "API configuration error" }, status: :internal_server_error
        return
      end

      Rails.logger.info "Making submit API status call for: #{auth_id}"
      response = HTTP.auth("Bearer #{api_key}")
                     .get("https://submit.hackclub.com/api/authorize/#{auth_id}/status")

      Rails.logger.info "Submit API response status: #{response.status}, body: #{response.body}"

      if response.status.success?
        render json: response.parse
      else
        Rails.logger.error "Submit API returned non-success status: #{response.status}"
        render json: { error: "Failed to check authorization status" }, status: :bad_request
      end
    rescue => e
      Rails.logger.error "Submit status check failed: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join(', ')}"
      render json: { error: "Failed to check authorization status" }, status: :internal_server_error
    end
  end
end
