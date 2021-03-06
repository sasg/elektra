module ServiceUser
  def self.included(base)
    base.send :helper_method, :service_user
  end

  def service_user
    return @service_user if @service_user_loaded
    
    friendly_id = FriendlyIdEntry.find_by_class_scope_and_key_or_slug('Domain',nil,params[:domain_id])
    scope_domain = friendly_id.nil? ? (params[:domain_id] || Rails.configuration.default_domain) : friendly_id.key
    
    @service_user_loaded = true
    # it can raise an error (will be catched by ScopeController)
    @service_user = Core::ServiceUser::Base.load({
      scope_domain: scope_domain,
      user_id: Rails.application.config.service_user_id,
      password: Rails.application.config.service_user_password,
      user_domain: Rails.application.config.service_user_domain_name 
    })   
  end
  
end