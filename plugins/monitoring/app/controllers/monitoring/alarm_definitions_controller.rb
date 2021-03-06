module Monitoring
  class AlarmDefinitionsController < Monitoring::ApplicationController
    authorization_required
    
    before_filter :load_alarm_definition, except: [ 
      :index, 
      :new,
      :from_expression_wizzard_new,
      :create,
      :search,
      :create_expression,
      :dimensions_for_metric,
      :dimension_row,
      :statistics,
      :edit_expression,
      :dimension_values,
      :metric_names_by_dimension
    ]
    
    def index
      @context = 'alarm_definitions'
      alarm_definition_search = cookies[:alarm_definitions_search] || ''
      unless alarm_definition_search.empty?
        search
      else
        all_alarm_definitions = services.monitoring.alarm_definitions
        @alarm_definitions_count = all_alarm_definitions.length
        @alarm_definitions = Kaminari.paginate_array(all_alarm_definitions).page(params[:page]).per(10)
      end
    end

    def search
      @search = params[:search] || cookies[:alarm_definitions_search] || ''
      searched_alarm_definitions = services.monitoring.alarm_definitions(@search)
      @alarm_definitions_count = searched_alarm_definitions.length
      @alarm_definitions = Kaminari.paginate_array(searched_alarm_definitions).page(params[:page]).per(10)
    end

    def show
      notification_methods = services.monitoring.notification_methods
      @notification_methods_hash = {}
      notification_methods.each{|notification_method| @notification_methods_hash[notification_method.id] = notification_method }
      parse_expression(@alarm_definition.expression)
    end

    def edit
      @expression = @alarm_definition.expression
      parse_expression(@expression)
      @notification_methods = services.monitoring.notification_methods.sort_by(&:name)
    end

    def new
      @head = 'New Alarm Definition'
      @alarm_definition = services.monitoring.new_alarm_definition(name: "")
      @notification_methods = services.monitoring.notification_methods.sort_by(&:name)
    end
    
    # this is used when the generated expression is transferred to the create alarm definitions view
    def from_expression_wizzard_new
      @head = 'Create Alarm Definition'
      expression = params['expression'] || ''
      # remember on values from the alarm creation dialog
      @name                 = params[:alarm_definition_name] || ''
      @description          = params[:alarm_definition_description] || ''
      @severity             = params[:alarm_definition_severity] || ''
      @actions_enabled      = params[:alarm_definition_actions_enabled] || 0
      @ok_actions           = params[:alarm_definition_ok_actions].split(/ /) || []
      @alarm_actions        = params[:alarm_definition_alarm_actions].split(/ /) || []
      @undetermined_actions = params[:alarm_definition_undetermined_actions].split(/ /) || []

      filter_by_dimensions = params['filter_by_dimensions']
      @filter_by = filter_by_dimensions.split(/,/) if filter_by_dimensions || []
      
      @alarm_definition = services.monitoring.new_alarm_definition(
        name: @name,
        expression: expression,
        description: @description,
        severity: @severity,
        actions_enabled: @actions_enabled,
        ok_actions: @ok_actions,
        alarm_actions: @alarm_actions,
        undetermined_actions: @undetermined_actions,
      )
      
      @notification_methods = services.monitoring.notification_methods.sort_by(&:name)
      render action: 'new_with_expression'
    end

    # this is used when the modified expression is transferred to the edit alarm definitions view
    def from_expression_wizzard_edit
      @expression = params[:expression]
      parse_expression(@expression)
      if @expression 
        @alarm_definition.expression = @expression
      end
      @notification_methods = services.monitoring.notification_methods.sort_by(&:name)
      render action: 'edit_with_expression'
    end

    def create
      @alarm_definition = services.monitoring.new_alarm_definition(params.require(:alarm_definition))

      unless @alarm_definition.save
        @notification_methods = services.monitoring.notification_methods.sort_by(&:name)
        render action: 'new'
        return
      end
      
      # https://github.com/sapcc/monasca-api/blob/master/docs/monasca-api-spec.md#create-alarm-definition
      # some how it is not possible to create an alarm with disabled alarm_actions and by default 
      # it is enabled so this should do the trick to disable alarm actions
      # when actions are zero (or no alarm action was selected) do an update with
      # the same params for creation and alarm actions should be deactivated
      if params['alarm_definition']['actions_enabled'].to_i == 0 or (
         !params['alarm_definition'].key?('ok_actions') and 
         !params['alarm_definition'].key?('alarm_actions') and 
         !params['alarm_definition'].key?('undetermined_actions')
         )
        params['alarm_definition']['actions_enabled'] = 0
        update 
      else
        back_to_alarm_definition_list
      end
    end

    def update
      attrs = params.require(:alarm_definition).permit(
        :name, 
        :description, 
        :expression, 
        :severity, 
        :match_by, 
        :actions_enabled, 
        # http://stackoverflow.com/questions/16549382/how-to-permit-an-array-with-strong-parameters
        # To declare that the value in params must be an array of permitted scalar values map the key to an empty array
        { ok_actions: [] },
        { alarm_actions: [] },
        { undetermined_actions: [] },
      ) 
      
      # disable actions if no alarm action was selected
      if params['alarm_definition']['actions_enabled'].to_i == 0 or (
         !params['alarm_definition'].key?('ok_actions') and 
         !params['alarm_definition'].key?('alarm_actions') and 
         !params['alarm_definition'].key?('undetermined_actions')
         )
         attrs[:actions_enabled] = 0
      end
      
      # allow to deselect all actions
      attrs["ok_actions"] = [] if !params['alarm_definition'].key?('ok_actions')
      attrs["alarm_actions"] = [] if !params['alarm_definition'].key?('alarm_actions')
      attrs["undetermined_actions"] = [] if !params['alarm_definition'].key?('undetermined_actions')

      unless @alarm_definition.update_attributes(attrs)
        @notification_methods = services.monitoring.notification_methods.sort_by(&:name)
        render action: 'edit'
        return
      end
      back_to_alarm_definition_list
    end

    def destroy 
      @alarm_definition.destroy
      back_to_alarm_definition_list
    end

    # get statistics for given expression
    def statistics
      metric     = params.require('metric')
      dimensions = params['dimensions'] || ''
      period     = params.require('period')
      threshold  = params.require('threshold')
      statistical_function = params.require('statistical_function')
      
      columns = []
      if statistical_function == 'avg' || 
         statistical_function == 'min' ||
         statistical_function == 'max'
         statistical_function = 'avg,min,max'
         columns = ['avg','max','min','threshold']
      else
        columns << statistical_function
        columns << 'threshold'
      end

      # get the statistic data for the last 120 minutes
      t = Time.now.utc - (60*120)
      statistics = services.monitoring.list_statistics({
        name: metric, 
        start_time: t.iso8601,
        statistics: statistical_function,
        dimensions: dimensions.gsub(/=/,':'),
        period: period,
        merge_metrics: true
      })
      
      data = [];
      columns.each do |column|
        values = [];
        x = 0;
        if statistics
          statistics.statistics.each do |statistic|
            if column == 'threshold'
              values << {x: x, y: threshold}
            else
              current_value = statistic[statistics.columns.find_index(column)]
              # round values
              current_value = current_value.round(2) if current_value.is_a? Numeric
              values << {x: x, y: current_value}
            end
            x +=period.to_i/60
          end
          data << {key: column, values: values}
        end
      end

      render json: data
    end

    def toggle_alarm_actions
      attrs = { 
        actions_enabled: !@alarm_definition.actions_enabled,
      } 
      
      @alarm_definition.update_attributes(attrs)
    end
    
    # edit a predefined expression
    # it is only allowed to change statistical functions, period and threshold
    def edit_expression
      @expression = params.require(:expression)
      @alarm_definition_id = params.require(:alarm_definition_id)
      @after_login = plugin('monitoring').alarm_definitions_path();
      parse_expression(@expression)
    end
    
    # create a new expression from scratch
    def create_expression
      
      # remember on values from the alarm creation dialog
      @name                 = params[:name]
      @description          = params[:description]
      @severity             = params[:severity]
      @actions_enabled      = params[:actions_enabled]
      @ok_actions           = params[:ok_actions]
      @alarm_actions        = params[:alarm_actions]
      @undetermined_actions = params[:undetermined_actions]
      
      @after_login = plugin('monitoring').alarm_definitions_path(overlay: 'create_expression')
      
      # this used on prefilter label
      @metrics_title = "use unfiltered metrics list"
      # this is used for metrics list label on the expression wizard
      @metrics_list_title = "Metrics - unfiltered"
      @metric_names = services.monitoring.get_metric_names()
    end
    
    def metric_names_by_dimension
      name = params.require(:name)
      value = params.require(:value)
      # this used on prefilter label
      @metrics_title = "to use a prefiltered metrics list"
      # this is used for metrics list label on the expression wizard
      @metrics_list_title = "Metrics - filtered"
      @metric_names = services.monitoring.get_metric_names({dimensions: name+":"+value})
      render partial: "metrics"
    end

    def dimension_values
      @name = params.require(:name)
      @dimensions = services.monitoring.get_dimension_values_by_dimension_name(@name)
      # because of ajax call we render the partial
      render partial: "dimension_values"
    end
    
    # used by the wizard to get once all dimensions for given metric name
    def dimensions_for_metric
      name = params.require(:name)
      # get all dimensions 120 minutes ago
      t = Time.now.utc - (60*120)
      metrics = services.monitoring.get_metric({
        name: name, 
        start_time: t.iso8601
      })
      
      # default init with empty array
      dimensions = Hash.new{ |h, k| h[k] = [] }
      metrics.map{ |metric| metric.dimensions.select{ |key, value| dimensions[key] << value }}
      render json: { dimensions: dimensions }
    end

    # used by wizard to render a new dimension row
    def dimension_row
      @cnt = params.require(:cnt).to_i
      @keys = JSON.parse(params.require(:keys));
      @next = @cnt + 1
      # because of ajax call we render the partial
      render partial: "dimension_row"
    end

    private
    
    def parse_expression(expression_original)

      # at the moment period, statistical function and dimensions are optional
      #  - period is set with 60 seconds, if it is not existing
      #  - statistical function is set with avg, if it is not existing
      # metric, threshold and threshold value are required
      
      expression = expression_original.clone
      # check for compounded expression
      if expression =~ /(\sor\s|\sand\s)/i
         # compounded espressions are not supported
         @parsed_expression_success = false
         return
      end
      
      # remove all white spaces for better parsing
      expression.gsub!(/\s/,'')
      # parse expression (/i case insensitive)
      result = expression.scan(/(avg|min|max|sum|count|\w+(\.?\w+)*|\{.*\}|<=|<|>=|>|\d*\.?\d+)/i)

      dimensions_string           = ""
      period_string               = ""
      statistical_function_string = ""
      begin
        # puts '###################'
        # pp result
        # puts '###################'
        
        #check existing statistical function
        if result[0][0] =~ /avg|min|max|sum|count/i
          @statistical_function = result[0][0]
          statistical_function_string = result[0][0]
        else
          # use avg as default value
          @statistical_function = "avg"
          # without statistical function we need to take care of the correct order
          result.insert(0,result[0])
        end

        @metric = result[1][0] || 'ERROR'

        # check existing dimensions
        if result[2][0] =~ /\{.*\}/
          @dimensions = result[2][0]
          dimensions_string = result[2][0].clone
          # for later use we do not need the brackets
          @dimensions.slice!('}')
          @dimensions.slice!('{')
        else 
          # without dimensions we need to take care of the correct order
          result.insert(2,result[2])
        end

        # check existing period
        if result[3][0] =~ /\A[-+]?[0-9]*\.?[0-9]+\Z/
          @period = result[3][0]
          period_string = ","+@period
        else
          # use 60 seconds as default value
          @period = 60
          # without period we need to take care of the correct order
          result.insert(3,result[3])
        end
        
        @threshold       = result[4][0] || 'ERROR'
        @threshold_value = result[5][0] || 'ERROR'
        
        # rebuild the brackets for validity check
        unless statistical_function_string.empty?
          statistical_function_string = statistical_function_string+"("
          if period_string.empty?
            dimensions_string = dimensions_string+")"
          else
            period_string = period_string+")"
          end
        end
        
        # rebuild expression to check if everything was going right
        @parsed_expression = statistical_function_string+@metric+dimensions_string+period_string+@threshold+@threshold_value
        #  puts @parsed_expression
        #  puts expression
        @parsed_expression_success = @parsed_expression == expression
      rescue
        @parsed_expression = "Cannot parse! This expression was probably not created with the expression wizard."
        @parsed_expression_success = false
      end 
    end

    def back_to_alarm_definition_list
      # only load the alarm defintions list
      respond_to do |format|
        format.js do
          index
          render action: 'reload_list'
        end
        # render index site
        format.html { redirect_to plugin('monitoring').alarm_definitions_path() }
      end
    end

    def load_alarm_definition
      id = params[:id] || params["id"]
      @alarm_definition = services.monitoring.get_alarm_definition(id)
      # @alarm_definition is loaded before destroy and update so we only need to take care in one place
      raise ActiveRecord::RecordNotFound, "The alarm definition with id #{params[:id]} was not found. Maybe it was deleted from someone else?" unless @alarm_definition.try(:id)
    end

  end
end
