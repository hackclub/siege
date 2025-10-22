class Admin::MystereepleShopItemsController < AdminController
  before_action :set_shop_item, only: [:show, :edit, :update, :destroy]

  def index
    @shop_items = MystereepleShopItem.all.order(:name)
  end

  def show
    @purchases = @shop_item.shop_purchases.includes(:user).order(purchased_at: :desc)
  end

  def new
    @shop_item = MystereepleShopItem.new
  end

  def create
    @shop_item = MystereepleShopItem.new(shop_item_params)

    if @shop_item.save
      current_user.add_audit_log(
        action: "created_mystereeple_shop_item",
        actor: current_user,
        details: { item_id: @shop_item.id, name: @shop_item.name, cost: @shop_item.cost, limit: @shop_item.limit }
      )
      redirect_to admin_mystereeple_shop_items_path, notice: 'Mystereeple shop item was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @shop_item.update(shop_item_params)
      current_user.add_audit_log(
        action: "updated_mystereeple_shop_item",
        actor: current_user,
        details: { item_id: @shop_item.id, name: @shop_item.name, cost: @shop_item.cost, limit: @shop_item.limit }
      )
      redirect_to admin_mystereeple_shop_items_path, notice: 'Mystereeple shop item was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shop_item.destroy
    current_user.add_audit_log(
      action: "deleted_mystereeple_shop_item",
      actor: current_user,
      details: { item_id: @shop_item.id, name: @shop_item.name }
    )
    redirect_to admin_mystereeple_shop_items_path, notice: 'Mystereeple shop item was successfully deleted.'
  end

  private

  def set_shop_item
    @shop_item = MystereepleShopItem.find(params[:id])
  end

  def shop_item_params
    params.require(:mystereeple_shop_item).permit(:name, :description, :cost, :limit, :enabled, :image)
  end
end
