Rails.application.config.session_store :cookie_store,
  key: "_siege_session",
  expire_after: 1.month,
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax
