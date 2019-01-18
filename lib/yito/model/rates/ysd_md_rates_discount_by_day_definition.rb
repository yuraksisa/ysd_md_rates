require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
  	  class DiscountByDayDefinition
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_discount_by_day_defs' 
  	  	
        property :id, Serial
  	  	property :name, String, :length => 80
  	  	property :description, String, :length => 255

        has n, :discount_by_days, :child_key => [:discount_by_day_definition_id], 
               :parent_key => [:id], :constraint => :destroy, :order => [:from_days.asc]

        #
        # Make a copy of a discount by day definition to be stored
        #
        def make_copy
          attributes = self.attributes.select {|k,y| k != :id}
          discount_by_day_attributes = self.discount_by_days.map { |discount_by_day| discount_by_day.attributes.select {|k,v| k != :id} }
          dbd_def = DiscountByDayDefinition.new(attributes)
          discount_by_day_attributes.each do |dbd_attributes|
            dbd_def.discount_by_days << DiscountByDay.new(dbd_attributes)
          end
          return dbd_def
        end

        # Get the factor for a number of days        
        def discount(days)
          discount_by_day_item = DiscountByDay.first(conditions: {:from_days.lte => days},
                                                     order: [:from_days.desc],
                                                     limit: 1)
          discount_by_day_item.nil? ? 0 : discount_by_day_item.discount
        end

      end
    end
  end
end