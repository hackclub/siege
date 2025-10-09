class TransitionProjectsToWaitingOnReviewJob < ApplicationJob
  queue_as :default

  def perform
    current_week = ApplicationController.helpers.current_week_number
    is_saturday = Time.current.saturday?
    
    # On Saturday, we can transition projects from the previous week (current_week - 1)
    # On any other day, only transition projects from older weeks (< current_week - 1)
    # This allows catching up on old projects while respecting the current voting period
    
    projects_to_transition = Project.where(status: "pending_voting")
    
    count = 0
    projects_to_transition.find_each do |project|
      project_week = ApplicationController.helpers.week_number_for_date(project.created_at)
      
      # Determine if this project should be transitioned
      should_transition = if is_saturday
        # On Saturday, transition previous week and older
        project_week < current_week
      else
        # On other days, only transition weeks before the previous week
        project_week < current_week - 1
      end
      
      if should_transition
        if project.update(status: "waiting_for_review")
          count += 1
          Rails.logger.info "[TransitionProjectsToWaitingForReview] Transitioned project #{project.id} (week #{project_week}) to waiting_for_review"
        else
          Rails.logger.error "[TransitionProjectsToWaitingForReview] Failed to transition project #{project.id}: #{project.errors.full_messages.join(', ')}"
        end
      else
        Rails.logger.debug "[TransitionProjectsToWaitingForReview] Skipped project #{project.id} (week #{project_week}) - still in voting period"
      end
    end
    
    Rails.logger.info "[TransitionProjectsToWaitingForReview] Transitioned #{count} projects to waiting_for_review status (Saturday: #{is_saturday})"
  end
end
