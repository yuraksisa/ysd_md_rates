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

      end
    end
  end
end