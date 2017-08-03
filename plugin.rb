# name: discourse-pm-scanner
# about: Discourse plugin that scan PM's with specific keywords and will notify admin if find any
# authors: Muhlis Budi Cahyono (muhlisbc@gmail.com)
# version: 0.1
# url: http://git.dev.abylina.com/momon/discourse-pm-scanner

enabled_site_setting :pm_scanner_enabled

after_initialize {

  self.add_model_callback(Post, :after_save) {
    if SiteSetting.pm_scanner_enabled
      keywords = SiteSetting.pm_scanner_keywords.to_s.split(",").map{ |k| Regexp.escape(k.strip) }

      if !keywords.blank?
        post_topic = self.topic

        if post_topic.private_message?
  
          regexp = Regexp.new(keywords.join("|"), Regexp::IGNORECASE)
  
          if match_data = self.raw.match(regexp) # nil or MatchData
  
            admins = User.where(admin: true).pluck(:id) # collect admin ids
            users  = post_topic.topic_users.pluck(:id) # collect users
  
            if (admins & users).empty? # if admins are not in the conversation

              admins.select{ |adm_id| adm_id > 0 }.each do |adm_id| # notify ONLY human admins
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