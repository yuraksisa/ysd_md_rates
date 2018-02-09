require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
  	  class FactorDefinition
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_factor_defs' 
  	  	
        property :id, Serial
  	  	property :name, String, :length => 80
  	  	property :description, String, :length => 255

        has n, :factors, :child_key => [:factor_definition_id], :parent_key => [:id], :constraint => :destroy, :order => [:from.asc]

        #
        # Make a copy of a season ready to be stored
        #
        def make_copy
          attributes = self.attributes.select {|k,y| k != :id}
          factors_attributes = self.factors.map { |factor| factor.attributes.select {|k,v| k != :id} }
          fd = FactorDefinition.new(attributes)
          factors_attributes.each do |factor_attributes|
            fd.factors << Factor.new(factor_attributes)
          end
          return fd
        end

        # Get the factor for a number of units         
        def factor(units)
          factor_item = Factor.first(:from.lte => units, :to.gte => units)
          factor_item.nil? ? 1 : factor_item.factor
        end

      end
    end
  end
end