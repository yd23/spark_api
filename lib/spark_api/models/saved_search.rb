module SparkApi
  module Models

    class SavedSearch < Base 
      extend Finders
      include Concerns::Savable,
              Concerns::Destroyable

      self.element_name="savedsearches"

      def self.provided()
        Class.new(self).tap do |provided|
          provided.element_name = '/savedsearches'
          provided.prefix = '/provided'
          SparkApi.logger.info("#{self.name}.path: #{provided.path}")
        end
      end

      def self.tagged(tag, arguments={})
        collect(connection.get("/#{self.element_name}/tags/#{tag}", arguments))
      end

      # list contacts (private role)
      def contacts
        return [] unless persisted?
        results = connection.get("#{self.class.path}/#{@attributes["Id"]}")
        @attributes['ContactIds'] = results.first['ContactIds']
      end

      # attach/detach contact (private role)
      [:attach, :detach].each do |action|
        method = (action == :attach ? :put : :delete)
        define_method(action) do |contact|
          self.errors = []
          contact_id = contact.is_a?(Contact) ? contact.Id : contact
          begin
            connection.send(method, "#{self.class.path}/#{@attributes["Id"]}/contacts/#{contact_id}")
          rescue BadResourceRequest => e
            self.errors << { :code => e.code, :message => e.message }
            SparkApi.logger.warn("Failed to #{action} contact #{contact}: #{e.message}")
            return false
          rescue NotFound => e
            self.errors << { :code => e.code, :message => e.message }
            SparkApi.logger.error("Failed to #{action} contact #{contact}: #{e.message}")
            return false
          end
          update_contacts(action, contact_id)
          true
        end
      end

      # This section is on hold until https://jira.fbsdata.com/browse/API-2766 has been completed.
      # 
      # return the newsfeed attached to this saved search
      # def newsfeeds
      #   Newsfeed.find(:all, :_filter => "Subscription.Id Eq '#{@attributes["Id"]}'")
      # end

      # def newsfeed_for(user)
      #   self.newsfeeds.select { |feed| feed.OwnerId == user.Id } 
      # end

      def can_have_newsfeed?

        standard_fields = %w(BathsTotal BedsTotal City CountyOrParish ListPrice Location MlsStatus PostalCode PropertyType RoomsTotal State)

        number_of_filters = 0

        standard_fields.each do |field|
          number_of_filters += 1 if self.Filter.include? field
        end
        
        number_of_filters >= 3

      end

      def has_newsfeed?
        if self.respond_to? "NewsFeedSubscriptionSummary"
          self.NewsFeedSubscriptionSummary['ActiveSubscription']
        else
          saved_search = SavedSearch.find( self.Id, {"_expand" => "NewsFeedSubscriptionSummary"})
          saved_search.NewsFeedSubscriptionSummary['ActiveSubscription']
        end
      end

      private

      def resource_pluralized; "SavedSearches" end

      def update_contacts(method, contact_id)
        @attributes['ContactIds'] = [] if @attributes['ContactIds'].nil?
        case method
        when :attach
          @attributes['ContactIds'] << contact_id
        when :detach
          @attributes['ContactIds'].delete contact_id
        end
      end

    end

  end
end
