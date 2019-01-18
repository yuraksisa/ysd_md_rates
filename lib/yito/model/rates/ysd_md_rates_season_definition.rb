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

        has n, :seasons, :child_key => [:season_definition_id], :parent_key => [:id], 
               :constraint => :destroy, :order => [:from_month, :from_day]
        
        #
        # Make a copy of a season ready to be stored
        # 
        def make_copy
          attributes = self.attributes.select {|k,y| k != :id}
          seasons_attributes = self.seasons.map { |season| season.attributes.select {|k,v| k != :id} }
          sd = SeasonDefinition.new(attributes)
          seasons_attributes.each do |season_attributes|
            sd.seasons << Season.new(season_attributes)
          end
          return sd
        end
        
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

        #
        # Get the season days
        #
        # @return [Hash] where the key is the season and the value the number of days in this season
        #
        def seasons_days(date, days)
          return nil if date.nil?

          built_result = self.seasons.inject({}) do |result, season|
            season_days = season.days(date, days)
            if season_days > 0
              result.store(season, season_days)
            end
            result
          end
          
          return built_result

        end

        #
        # Get the seasons ordered by date
        #
        def seasons_by_date

          seasons.sort { |x,y| x.from_month == y.from_month ? x.from_day <=> y.from_day : x.from_month <=> y.from_month }

        end

        #
        # Check if the seasons are valid : That is, they cover all year and there are not overlappings
        #
        def seasons_valid?

          seasons_errors.empty?

        end

        #
        # Check the seasons errors
        #
        def seasons_errors

          errors = {}

          seasons_sorted = seasons_by_date

          if seasons.size == 0
            errors.store(:common, ::Yito::Model::Rates.r18n.t.seasons_validation.no_seasons_defined)
          else

            first_season = seasons_sorted.first
            last_season = seasons_sorted.last

            if first_season.from_day != 1 or first_season.from_month != 1
              errors.store(first_season.id, ::Yito::Model::Rates.r18n.t.seasons_validation.first_season_start(first_season.name))
            end

            index = 1
            last_index = seasons_sorted.size - 1
            while index <= last_index do

              previous_month = seasons_sorted[index-1].to_month
              previous_day = seasons_sorted[index-1].to_day

              current_month = seasons_sorted[index].from_month
              current_day = seasons_sorted[index].from_day

              previous_month_calculated, previous_day_calculated = previous(current_month, current_day)

              if previous_month_calculated != previous_month or
                  previous_day_calculated != previous_day
                errors.store(seasons_sorted[index-1].id,
                             ::Yito::Model::Rates.r18n.t.seasons_validation.end_date(
                                 seasons_sorted[index-1].name,
                                 previous_day_calculated,
                                 ::Yito::Model::Rates.r18n.t.seasons_validation["month_#{previous_month_calculated}"]))
              end

              index += 1

            end

            if last_season.to_day != 31 or last_season.to_month != 12
              errors.store(last_season.id, ::Yito::Model::Rates.r18n.t.seasons_validation.last_season_end(last_season.name))
            end


          end

          return errors

        end

        private

        LAST_DAYS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

        #
        # Get the previous (month and day)
        #
        def previous(current_month, current_day)

          previous_month = nil
          previous_day = nil

          if current_month != 1 or current_day != 1
             if current_day == 1
               previous_month = current_month - 1
               previous_day = LAST_DAYS[previous_month-1]
             else
               previous_month = current_month
               previous_day = current_day - 1
             end
          end

          return [previous_month, previous_day]

        end


        #
        # Get the next (month and day)
        #
        def next(current_month, current_day)

          next_month = nil
          next_day = nil

          if current_month != 1 or current_day != 1
            if current_day == LAST_DAYS[current_month-1]
              next_month = current_month + 1
              next_day = 1
            else
              next_month = current_month
              next_day = current_day + 1
            end
          end

          return [next_month, next_day]

        end


      end
    end
  end
end