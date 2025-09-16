class Admin::CosmeticsController < AdminController
  before_action :set_cosmetic, only: [ :show, :edit, :update, :destroy ]

  def index
    @cosmetics = Cosmetic.all.order(:name)
  end

  def show
  end

  def new
    @cosmetic = Cosmetic.new
  end

  def create
    @cosmetic = Cosmetic.new(cosmetic_params)

    if @cosmetic.save
      redirect_to admin_cosmetics_path, notice: "Cosmetic was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @cosmetic.update(cosmetic_params)
      redirect_to admin_cosmetics_path, notice: "Cosmetic was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cosmetic.destroy
    redirect_to admin_cosmetics_path, notice: "Cosmetic was successfully deleted."
  end

  private

  def set_cosmetic
    @cosmetic = Cosmetic.find(params[:id])
  end

  def cosmetic_params
    params.require(:cosmetic).permit(:name, :description, :type, :cost, :purchasable, :image)
  end
end
