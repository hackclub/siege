module ProjectsHelper
  def can_create_project?
    return false unless current_user
    !current_user.has_project_this_week?(Date.current)
  end

  def project_creation_message
    error_message = current_user.project_creation_error
    error_message || "You can create a project!"
  end

  def display_url_or_placeholder(url, placeholder_text)
    if url.present?
      # Extract domain from URL
      begin
        uri = URI.parse(url)
        # Return the host (domain + subdomain) without protocol
        uri.host
      rescue URI::InvalidURIError
        # If URL parsing fails, return the original URL
        url
      end
    else
      content_tag(:em, placeholder_text)
    end
  end
end
