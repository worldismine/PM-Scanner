# name: discourse-pm-scanner
# authors: Muhlis Budi Cahyono (muhlisbc@gmail.com) and richard@communiteq.com
# version: 3.1.0
# url: https://github.com/worldismine/PM-Scanner

enabled_site_setting :pm_scanner_enabled

after_initialize {

  register_svg_icon("exclamation")

  add_model_callback(::Chat::Message, :after_save) {
    begin
      return unless SiteSetting.pm_scanner_enabled
      return unless self.chat_channel.chatable_type == "DirectMessage"
      admin_ids = Group[:admins].users.pluck(:id)
      return unless (::Chat::ChannelMembershipsQuery.call(channel: self.chat_channel).pluck(:user_id) & admin_ids).count

      keywords = SiteSetting.pm_scanner_keywords.to_s.split(",").map{ |k| Regexp.escape(k.strip) }
      regexp = Regexp.new(keywords.join("|"), Regexp::IGNORECASE)
      match_data = self.message.match(regexp) # nil or MatchData
      creator = self.user
      return unless match_data && creator && !creator.admin

      messages = self.chat_channel.chat_messages.where("id <= #{self.id}").order(created_at: :desc).limit(10)
      body = "[Open chat](/chat/channel/#{self.chat_channel.id}/open)\n\n"
      body += "|User|Date/Time|Message|\n|---|---|---|\n"
      messages.reverse_each do |msg|
        body += "|#{msg.user.username}|[date=#{msg.created_at.strftime('%Y-%m-%d')} time=#{msg.created_at.strftime('%H:%M:%S')} timezone=Etc/UTC]|#{msg.message.gsub("\n", " ").truncate(50)}|\n"
      end

      title = "#{match_data.to_s} found in direct chat message sent by #{self.user.username}"
      create_args = {
        archetype: Archetype.private_message,
        title: "PM Scanner: " + title.truncate(SiteSetting.max_topic_title_length, separator: /\s/),
        raw: ERB::Util.html_escape(body),
        target_group_names: [Group[:admins].name]
      }
      post = PostCreator.create!(Discourse.system_user, create_args)
      return unless post

      admin_ids.each do |adm_id| # notify ONLY human admins
        notif_payload = {topic_id: post.topic.id, user_id: adm_id, post_number: post.post_number, notification_type: Notification.types[:custom]}
        if Notification.where(notif_payload).first.blank?
          Notification.create(notif_payload.merge(data: {message: "pm_scanner.notification.found", display_username: match_data.to_s, topic_title: title}.to_json))
        end
      end
    rescue
    end
  }

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

  # admins need to be able to see the direct message chats
  module ::PMScannerDirectMessage
    def user_can_access?(user)
      return true if SiteSetting.pm_scanner_enabled && user.admin?
      super(user)
    end
  end

  class ::DirectMessage
    prepend PMScannerDirectMessage
  end

}
