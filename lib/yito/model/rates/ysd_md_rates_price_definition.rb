require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
  	  class PriceDefinition
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_price_defs' 
  	  	
  	  	property :id, Serial
  	  	property :name, String, :length => 80
        property :description, String, :length => 255
        property :max_price, Decimal, :scale => 2, :precision => 10
        property :base_price, Decimal, :scale => 2, :precision => 10
        property :type, Enum[:season, :no_season], :default => :no_season
    
        belongs_to :factor_definition, :required => false
        belongs_to :season_definition, :required => false

        has n, :prices, :child_key => [:price_definition_id], :parent_key => [:id], :constraint => :destroy      

        def save
          check_factor_definition! if self.factor_definition
          check_season_definition! if self.season_definition
          super
        end

        private 

        def check_factor_definition!
      
          if self.factor_definition and (not self.factor_definition.saved?) and loaded = FactorDefinition.get(self.factor_definition.id)
            self.factor_definition = loaded
          end

        end        

        def check_season_definition!
      
          if self.season_definition and (not self.season_definition.saved?) and loaded = SeasonDefinition.get(self.season_definition.id)
            self.season_definition = loaded
          end

        end        


      end
    end
  end
end