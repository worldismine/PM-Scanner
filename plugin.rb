# name: discourse-pm-scanner
# authors: Muhlis Budi Cahyono (muhlisbc@gmail.com)
# version: 0.5
# url: https://github.com/muhlisbc

enabled_site_setting :pm_scanner_enabled

after_initialize {

  register_svg_icon("exclamation")

  add_model_callback(:post, :after_save) {
    if SiteSetting.pm_scanner_enabled
      keywords = SiteSetting.pm_scanner_keywords.to_s.split(",").map{ |k| Regexp.escape(k.strip) }

      if !keywords.blank?
        post_topic = self.topic

        if post_topic.private_message?
  
          regexp = Regexp.new(keywords.join("|"), Regexp::IGNORECASE)
          match_data = self.raw.match(regexp) # nil or MatchData
          creator = self.user
  
          if match_data && creator && !creator.admin
            admin_ids = User.where("id > ?", 0).where(admin: true).pluck(:id)
            user_ids  = post_topic.topic_allowed_users.pluck(:user_id)
  
            if (admin_ids & user_ids).empty? # if admins are not in the conversation

              admin_ids.each do |adm_id| # notify ONLY human admins
                notif_payload = {topic_id: post_topic.id, user_id: adm_id, post_number: self.post_number, notification_type: Notification.types[:custom]}
                if Notification.where(notif_payload).first.blank?
                  Notification.create(notif_payload.merge(data: {message: "pm_scanner.notification.found", display_username: match_data.to_s, topic_title: post_topic.title}.to_json))
                end
              end

            end
          end
        end
      end
    end
  }

}
