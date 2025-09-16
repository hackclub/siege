class Admin::PhysicalItemsController < AdminController
  before_action :set_physical_item, only: [:show, :edit, :update, :destroy]

  def index
    @physical_items = PhysicalItem.all.order(:name)
  end

  def show
  end

  def new
    @physical_item = PhysicalItem.new
  end

  def create
    @physical_item = PhysicalItem.new(physical_item_params)

    if @physical_item.save
      redirect_to admin_physical_items_path, notice: 'Physical item was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @physical_item.update(physical_item_params)
      redirect_to admin_physical_items_path, notice: 'Physical item was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @physical_item.destroy
    redirect_to admin_physical_items_path, notice: 'Physical item was successfully deleted.'
  end

  private

  def set_physical_item
    @physical_item = PhysicalItem.find(params[:id])
  end

  def physical_item_params
    params.require(:physical_item).permit(:name, :description, :cost, :purchasable, :image)
  end
end
