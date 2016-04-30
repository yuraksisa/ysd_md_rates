require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
  	  class Price
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_prices' 
  	  	
        property :id, Serial
        property :price, Decimal, :scale => 2, :precision => 10        
        property :units, Integer
        property :adjust_operation, String, :length => 1, :format => /[*+-\/]|\s/, :default => ' '
        property :adjust_amount, Decimal, :scale => 2, :precision => 10
        
        belongs_to :price_definition, :child_key => [:price_definition_id], :parent_key => [:id]
        belongs_to :season, :required => false

        def apply_adjust(value)
          if adjust_operation == '*'
            return value * adjust_amount
          elsif adjust_operation == '+'
            return value + adjust_amount
          elsif adjust_operation == '-'
            return value - adjust_amount
          else
            return value
          end  
        end

        def save
          check_price_definition! if self.price_definition
          check_season! if self.season
          super
        end

        def as_json(options={})
     
          relationships = options[:relationships] || {}
          relationships.store(:season, {})
      
          super(options.merge({:relationships => relationships}))

        end

        def self.all_season_ordered(opts={})
          # @See http://rhnh.net/2010/12/01/ordering-by-a-field-in-a-join-model-with-datamapper
          if price_definition and price_definition.type == :season
            order_from_month = DataMapper::Query::Direction.new(season.from_month, :asc)
            order_from_day = DataMapper::Query::Direction.new(season.from_day, :asc)
            order_to_month = DataMapper::Query::Direction.new(season.to_month, :asc)
            order_to_day = DataMapper::Query::Direction.new(season.to_day, :asc)
          
            query = all.query # Access a blank query object for us to manipulate
            query.instance_variable_set("@order", [order_from_month, order_from_day, order_to_month, order_to_day])

            # Force the season model to be joined into the query
            query.instance_variable_set("@links", [relationships['season'].inverse])

            all(query) # && all(opts) # Create a new collection with the modified query
          else
            query = all.query
            all(query)
          end
        end

        private 

        def check_price_definition!
      
          if self.price_definition and (not self.price_definition.saved?) and loaded = PriceDefinition.get(self.price_definition.id)
            self.price_definition = loaded
          end

        end        

        def check_season!
      
          if self.season and (not self.season.saved?) and loaded = Season.get(self.season.id)
            self.season = loaded
          end

        end        


      end
    end
  end
end