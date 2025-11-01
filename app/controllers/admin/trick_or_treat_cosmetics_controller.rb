class Admin::TrickOrTreatCosmeticsController < AdminController
  def index
    @cosmetics = Cosmetic.all.order(:name)
  end

  def update_pool
    cosmetic_ids = params[:cosmetic_ids] || []
    
    Cosmetic.update_all(in_trick_or_treat_pool: false)
    
    if cosmetic_ids.any?
      Cosmetic.where(id: cosmetic_ids).update_all(in_trick_or_treat_pool: true)
    end
    
    redirect_to admin_trick_or_treat_cosmetics_path, notice: "Trick or treat cosmetic pool updated successfully."
  end
end
