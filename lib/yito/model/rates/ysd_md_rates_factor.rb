require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
  	  class Factor
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_factors' 
  	  	
        property :id, Serial
        property :from, Integer
        property :to, Integer
        property :factor, Decimal, :scale => 2, :precision => 10
        belongs_to :factor_definition
        	  	
        def save
          check_factor_definition! if self.factor_definition
          super
        end

        private 

        def check_factor_definition!
      
          if self.factor_definition and (not self.factor_definition.saved?) and loaded = FactorDefinition.get(self.factor_definition.id)
            self.factor_definition = loaded
          end

        end

      end
    end
  end
end