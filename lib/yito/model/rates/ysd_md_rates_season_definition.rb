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

      end
    end
  end
end