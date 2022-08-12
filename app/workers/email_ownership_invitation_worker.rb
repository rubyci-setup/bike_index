class EmailOwnershipInvitationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(ownership_id)
    ownership = Ownership.find_by_id(ownership_id)
    return true unless ownership.present? && ownership.bike.present?
    ownership.bike&.update(updated_at: Time.current)
    ownership.reload
    unless ownership.calculated_send_email
      # Update the ownership to have send email set
      return ownership.update_attribute(:send_email, ownership.calculated_send_email)
    end
    notification = Notification.find_or_create_by(notifiable: ownership,
      kind: "finished_registration")
    unless notification.delivered?
      OrganizedMailer.finished_registration(ownership).deliver_now
      notification.update(delivery_status: "email_success") # This could be made more representative
    end
  end
end
