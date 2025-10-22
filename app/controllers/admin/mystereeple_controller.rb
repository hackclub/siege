class Admin::MystereepleController < AdminController
  def index
    @windows = MystereepleWindow.all.order(:name)
    @shop_items = MystereepleShopItem.all.order(:name)
    @current_week = ApplicationController.helpers.current_week_number
  end

  def windows
    @windows = MystereepleWindow.all.order(:name)
  end

  def update_window_days
    window = MystereepleWindow.find(params[:id])
    window.update!(days_available: params[:days_available])
    
    current_user.add_audit_log(
      action: "updated_mystereeple_window",
      actor: current_user,
      details: { window_id: window.id, window_name: window.name, days_available: params[:days_available] }
    )
    
    render json: { success: true }
  rescue => e
    Rails.logger.error "Failed to update window days: #{e.message}"
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end

  def toggle_window
    window = MystereepleWindow.find(params[:id])
    window.update!(enabled: !window.enabled)
    
    current_user.add_audit_log(
      action: "toggled_mystereeple_window",
      actor: current_user,
      details: { window_id: window.id, window_name: window.name, enabled: window.enabled }
    )
    
    render json: { success: true, enabled: window.enabled }
  rescue => e
    Rails.logger.error "Failed to toggle window: #{e.message}"
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end
end
