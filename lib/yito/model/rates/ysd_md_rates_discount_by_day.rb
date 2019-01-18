require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
  	  class DiscountByDay
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_discount_by_days' 
  	  	
        property :id, Serial
        property :from_days, Integer
        property :discount, Decimal, :scale => 2, :precision => 10
        belongs_to :discount_by_day_definition
        	  	
        def save
          check_discount_by_day_definition! if self.discount_by_day_definition
          super
        end

        private 

        def check_discount_by_day_definition!
      
          if self.discount_by_day_definition and (not self.discount_by_day_definition.saved?) and 
             loaded = DiscountByDayDefinition.get(self.discount_by_day_definition.id)
            self.discount_by_day_definition = loaded
          end

        end

      end
    end
  end
end