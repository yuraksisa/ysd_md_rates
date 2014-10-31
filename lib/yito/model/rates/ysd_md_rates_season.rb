require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
  	  class Season
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_seasons' 
  	  	
        property :id, Serial
        property :name, String, :length => 80
        property :from_day, Integer
        property :from_month, Integer
        property :to_day, Integer
        property :to_month, Integer
        belongs_to :season_definition
        
        def save
          check_season_definition! if self.season_definition
          super
        end

        private 

        def check_season_definition!
      
          if self.season_definition and (not self.season_definition.saved?) and loaded = SeasonDefinition.get(self.season_definition.id)
            self.season_definition = loaded
          end

        end

      end
    end
  end
end