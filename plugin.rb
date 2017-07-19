# name: discourse-pm-scanner
# about: Discourse plugin that scan PM's with specific keywords and will notify admin if find any
# authors: Muhlis Budi Cahyono (muhlisbc@gmail.com)
# version: 0.1
# url: http://git.dev.abylina.com/momon/discourse-pm-scanner

enabled_site_setting :pm_scanner_enabled

after_initialize {
  module ::PMScanner
    def self.included(base)
      base.class_eval do
        after_save :pm_scanner_scan

        def pm_scanner_scan
          return if !SiteSetting.pm_scanner_enabled

          keywords = SiteSetting.pm_scanner_keywords.to_s
          return if keywords.blank?

          post_topic = self.topic
          return if !post_topic.private_message?

          regexp = Regexp.new(Regexp.escape(keywords))
          if match_data = self.raw.match(regexp) # nil or MatchData
            # WIP
            # User.where(admin: true).each do |adm|
            #   Notification.create(
            #     topic_id: post_topic.id,
            #     user_id: adm.id,
            #     post_number: self.post_number,
            #     notification_type: 14, # custom
            #     data: {}
            #   )
            # end
          end
        end
      end
    end
  end

  ::Post.send(:include, PMScanner)
}