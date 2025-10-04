class TransitionProjectsToWaitingOnReviewJob < ApplicationJob
  queue_as :default

  def perform
    # Only run on Thursdays
    return unless Time.current.thursday?

    # Find all projects that are in pending_voting status
    projects_to_transition = Project.where(status: "pending_voting")
    
    count = 0
    projects_to_transition.find_each do |project|
      if project.update(status: "waiting_for_review")
        count += 1
        Rails.logger.info "[TransitionProjectsToWaitingForReview] Transitioned project #{project.id} to waiting_for_review"
      else
        Rails.logger.error "[TransitionProjectsToWaitingForReview] Failed to transition project #{project.id}: #{project.errors.full_messages.join(', ')}"
      end
    end
    
    Rails.logger.info "[TransitionProjectsToWaitingForReview] Transitioned #{count} projects to waiting_for_review status"
  end
end
