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
          	  	
      end
    end
  end
end