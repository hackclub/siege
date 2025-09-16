class CountdownController < ApplicationController
  skip_before_action :require_authentication
  layout "countdown"

  def index
  end
end
