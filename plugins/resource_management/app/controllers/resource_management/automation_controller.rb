require_dependency "resource_management/application_controller"

module ResourceManagement
  class AutomationController < ::ResourceManagement::ApplicationController

    # requires cloud_admin permission to use (intended for use with a privileged technical user)
    authorization_required

    # bypass Terms-of-Use check for technical users
    def check_terms_of_use
      return
    end

    def sync_domain
      domain_name = params.require(:domain_name)
      domain = services.identity.domains(name: domain_name).first
      if domain.nil?
        render plain: "ERROR: cannot find domain \"#{domain_name}\"", status: :bad_request
        return
      end

      # sync quota/usage data for domain and projects in this domain
      begin
        services.resource_management.sync_domain(
          domain.id, domain_name,
          timeout_secs: 50,   # abort after 50 seconds to avoid HTTP connection timeout (~1 minute)
          refresh_secs: 1800, # do not try to update data that's newer than 30 minutes ago
        )
      rescue Interrupt
        # not yet done - restart the sync by redirecting the client to the same
        # URL (this might look like an infinite redirect, so the client should
        # be prepared to handle a long redirection chain,
        # e.g. `curl -L --max-redirs -1`)
        redirect_to plugin('resource_management').automation_sync_domain_url(
          project_id:  @scoped_project_name,
          domain_id:   @scoped_domain_name,
          domain_name: domain_name,
        )
        return
      end

      # sync finished - tell the client to sleep until the first data becomes stale again
      min_updated_at = ResourceManagement::Resource.where(domain_id: domain.id).minimum(:updated_at)
      sleep_seconds = (((min_updated_at + 1800.seconds) - Time.now) / 1.second).round
      render plain: "please sleep for #{sleep_seconds} seconds", status: :ok
    end

    def dump_data
      region = [Rails.application.config.default_region].flatten.first
      monsoon2_domain_id = ResourceManagement::Resource.where(scope_name: 'monsoon2', project_id: nil).pluck(:domain_id).first
      # when dumping project resource data, skip internal dummy records with service == "resource_management"
      project_resources = ResourceManagement::Resource.where("project_id IS NOT NULL AND service != 'resource_management' AND domain_id != ?", monsoon2_domain_id)

      full_data = {
        metadata: { version: 1 },
        data: project_resources.map do |res|
          dt = res.data_type
          {
            domain_id: res.domain_id,
            project_id: res.project_id,
            resource_class: res.service,
            resource_type: res.name,
            quota: dt.normalize(res.current_quota),
            usage: dt.normalize(res.usage),
            last_information_at: res.updated_at.iso8601,
            region: region,
          }
        end,
      }
      render json: full_data.to_json
    end

    def make_everything_okay
      messages = []
      resources = ResourceManagement::Resource.where(service: 'dns', name: 'recordsets').where.not(project_id: nil).to_a
      resources.each do |res|
        # re-apply recordset quotas to set the records quota which is now derived from the recordsets quota
        failed_services = services.resource_management.apply_current_quota(res)
        if failed_services.size > 0
          messages.append("dns/records quota reset failed for project #{res.project_id} (#{res.scope_name} in domain #{res.domain_id})")
        end
      end

      messages.unshift("#{resources.size} quotas touched")
      render plain: messages.join("\n")
    end

  end
end
