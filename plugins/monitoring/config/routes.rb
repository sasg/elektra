Monitoring::Engine.routes.draw do
  get '/' => 'entry#index', as: 'entry'
  get 'overview' => 'overview#index'

  resources 'alarms', except: [:new, :create] do
    collection do
      get 'filter' => 'alarms#filter_and_search'
      get 'search' => 'alarms#filter_and_search'
    end
    get 'history'
  end

  resources 'alarm_definitions' do
    collection do
      get   'search'
      match 'create_expression' => 'alarm_definitions#create_expression' , :via => [:get, :post]
      post  'dimension_values'
      post  'metric_names_by_dimension'
      get   'edit_expression'
      post  'dimensions_for_metric' 
      post  'dimension_row'
      post  'statistics'
      post  'from_expression_wizzard_new'
      post  'from_expression_wizzard_edit'
    end
    member do
      get 'toggle_alarm_actions'
    end
  end

  resources 'notification_methods' do
    collection do
      get 'search'
    end
  end

end
