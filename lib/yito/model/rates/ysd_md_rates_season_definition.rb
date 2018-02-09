require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
  	  class SeasonDefinition
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_season_defs' 
  	  	
  	  	property :id, Serial
  	  	property :name, String, :length => 80
  	  	property :description, String, :length => 255

        has n, :seasons, :child_key => [:season_definition_id], :parent_key => [:id], :constraint => :destroy
        
        #
        # Make a copy of a season ready to be stored
        # 
        def make_copy
          attributes = self.attributes.select {|k,y| k != :id}
          seasons_attributes = self.seasons.map { |season| season.attributes.select {|k,v| k != :id} }
          sd = SeasonDefinition.new(attributes)
          seasons_attributes.each do |season_attributes|
            sd.seasons << Season.new(season_attributes)
          end
          return sd
        end
        
        #
        # Get the season from a date
        #
        def season(date)
          unless date.nil?
            selected_seasons = seasons.select do |season|
              date_from = Date.civil(date.year, season.from_month, season.from_day)
              date_to = Date.civil(date.year, season.to_month, season.to_day)
              date.to_date >= date_from and date.to_date <= date_to
            end 
            selected_seasons.first
          end
        end

        #
        # Get the season days
        #
        # @return [Hash] where the key is the season and the value the number of days in this season
        #
        def seasons_days(date, days)
          return nil if date.nil?

          built_result = self.seasons.inject({}) do |result, season|
            season_days = season.days(date, days)
            if season_days > 0
              result.store(season, season_days)
            end
            result
          end
          
          return built_result

        end
        
      end
    end
  end
end