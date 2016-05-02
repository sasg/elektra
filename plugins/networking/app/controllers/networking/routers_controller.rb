module Networking
  class RoutersController < DashboardController
    
    # routers(filter={})
    # get_router(router_id)
    # create_router(name,params)
    # update_router(id, params)
    # delete_router(id)
    
    
    def index
      @routers = services.networking.routers(tenant_id:@scoped_project_id)
      # @router_gateway_ports = services.networking.ports(device_owner: "network:router_gateway")
      # @router_interface_ports = services.networking.ports(device_owner: "network:router_interface")
      # router_ids = []
    end

    def show
      @router = services.networking.find_router(params[:id])
      @router_gateway_ports = services.networking.ports(device_id: params[:id])
      @router_interface_ports = services.networking.ports(device_id: params[:id])
      
      
      @topology_graph = {
        name: @router.name,
        children: @router_gateway_ports.collect{|port| {name: port.name}} + @router_gateway_ports.collect{|port| {name: port.name}}
      }
    end

    #
    # def new
    #   @network = services.networking.network
    # end
    #
    # def create
    #   @network = services.networking.network
    #
    #   network_params = params[@network.model_name.param_key]
    #   subnets_params = network_params.delete(:subnets)
    #
    #   @network.attributes = network_params
    #
    #   if @network.save
    #
    #     if subnets_params
    #       subnet = services.networking.subnet
    #       subnet.attributes = subnets_params.merge("network_id"=>@network.id)
    #       puts subnet.pretty_attributes
    #       subnet.save
    #     end
    #
    #     flash[:notice] = "Network successfully created."
    #     redirect_to networks_path
    #   else
    #     render action: :new
    #   end
    # end
    #
    # def edit
    #   @network = services.networking.network(params[:id])
    # end
    #
    # def update
    #   @network = services.networking.network(params[:id])
    #   @network.attributes = params[@network.model_name.param_key]
    #   if @network.save
    #     flash[:notice] = "Network successfully updated."
    #     redirect_to networks_path
    #   else
    #     render action: :edit
    #   end
    # end
    #
    # def destroy
    #   @network = services.networking.network(params[:id]) rescue nil
    #
    #   if @network
    #     if @network.destroy
    #       flash[:notice] = "Network successfully deleted."
    #     else
    #       flash[:error] = network.errors.full_messages.to_sentence #"Something when wrong when trying to delete the project"
    #     end
    #   end
    #
    #   respond_to do |format|
    #     format.js {}
    #     format.html {redirect_to networks_path}
    #   end
    # end
  end
end
