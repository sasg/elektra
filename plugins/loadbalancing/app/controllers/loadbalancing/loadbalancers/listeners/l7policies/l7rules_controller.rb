module Loadbalancing
  module Loadbalancers
    module Listeners
      module L7policies
        class L7rulesController < DashboardController

          before_filter :load_objects, except: [:create]

          def index
            @l7rules = paginatable(per_page: 20) do |pagination_options|
              services.loadbalancing.l7rules(params[:l7policy_id], { sort_key: 'type', sort_dir: 'asc' }.merge(pagination_options))
            end
          end

          def new
            @l7rule = services.loadbalancing.new_l7rule
          end

          def create
            @l7rule = services.loadbalancing.new_l7rule
            @l7rule.attributes = l7rule_params.delete_if { |key, value| value.blank? }.merge(l7policy_id: params[:l7policy_id])
            if @l7rule.save
              audit_logger.info(current_user, "has created", @l7rule)
              redirect_to loadbalancer_listener_l7policy_l7rules_path(loadbalancer_id: params[:loadbalancer_id], listener_id: params[:listener_id], l7policy_id: params[:l7policy_id]), notice: 'L7 Rule created.'
            else
              load_objects
              render :new
            end
          end


          def destroy
            @l7rule = services.loadbalancing.find_l7rule(params[:l7policy_id], params[:id])
            services.loadbalancing.delete_l7rule(params[:l7policy_id], params[:id])
            audit_logger.info(current_user, "has deleted", @l7rule)
            render template: 'loadbalancing/loadbalancers/listeners/l7policies/l7rules/destroy_item.js'
          end


          def show
            @l7rule = services.loadbalancing.find_l7rule(params[:l7policy_id], params[:id])
          end

          def edit
            @l7rule = services.loadbalancing.find_l7rule(params[:l7policy_id], params[:id])
          end


          def update
            @l7rule = services.loadbalancing.find_l7rule(params[:l7policy_id], params[:id])
            if services.loadbalancing.update_l7rule(params[:l7policy_id], params[:id], l7rule_params)
              audit_logger.info(current_user, "has updated", @l7rule)
              redirect_to loadbalancer_listener_l7policy_l7rules_path(loadbalancer_id: params[:loadbalancer_id], listener_id: params[:listener_id], l7policy_id: @l7policy.id), notice: 'L7 Rule was successfully updated.'
            else
              render :edit
            end
          end

          # update instance table row (ajax call)
          def update_item
            begin
              @l7rule = services.loadbalancing.find_l7rule(params[:id])
              respond_to do |format|
                format.js do
                  @l7rule if @l7rule
                end
              end
            rescue => e
              return nil
            end
          end

          def release_state
            "experimental"
          end

          private

          def l7rule_params
            p = params[:l7rule]
            return p
          end

          def load_objects
            @loadbalancer = services.loadbalancing.find_loadbalancer(params[:loadbalancer_id])
            @listener = services.loadbalancing.find_listener(params[:listener_id])
            @l7policy = services.loadbalancing.find_l7policy(params[:l7policy_id])
          end

        end
      end
    end
  end
end
