require 'fog/openstack/billing'

module CostControl
  module Driver
    class Fog < Interface
      include Core::ServiceLayer::FogDriver::ClientHelper

      def get_project_metadata(project_id)
        handle_response do
          return { "id" => project_id, "cost_object_type" => "IO", "cost_object_id" => "0123456" } ## TODO: remove when service is available in staging
          metadata = fog.get_project_metadata(project_id).body['metadata']
          cost_object = metadata.fetch('cost_object', {})
          {
            'id'               => project_id,
            'cost_object_type' => cost_object['type'],
            'cost_object_id'   => cost_object['id'],
          }
        end
      end

      def update_project_metadata(project_id, params={})
        handle_response do
          return params ## TODO: remove when service is available in staging
          metadata = {
            'cost_object' => {
              'type' => params['cost_object_type'],
              'id'   => params['cost_object_id'],
            },
          }
          fog.put_project_metadata(project_id, metadata)
          params
        end
      end

      private

      def fog
        @fog ||= ::Fog::Billing::OpenStack.new(auth_params)
      end

    end
  end
end
