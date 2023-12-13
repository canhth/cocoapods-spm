require "cocoapods-spm/installer/analyzer"
require "cocoapods-spm/macro/pod_installer"
require "cocoapods-spm/macro/settings_updater"

module Pod
  class Installer
    include SPM::Config::Mixin

    alias origin_resolve_dependencies resolve_dependencies
    def resolve_dependencies
      origin_resolve_dependencies
      resolve_spm_dependencies
    end

    alias origin_create_pod_installer create_pod_installer
    def create_pod_installer(pod_name)
      if macro_pods.include?(pod_name)
        macro_pod_installer = MacroPodInstaller.new(
          sandbox,
          podfile,
          specs_for_pod(pod_name),
          can_cache: installation_options.clean?
        )
        pod_installers << macro_pod_installer
        macro_pod_installer
      else
        origin_create_pod_installer(pod_name)
      end
    end

    alias origin_integrate integrate
    def integrate
      run_spm_pre_integrate_hooks
      origin_integrate
      run_spm_post_integrate_hooks
    end

    private

    def run_spm_pre_integrate_hooks
      SPM::MacroSettingsUpdater.new(
        pod_targets: pod_targets,
        aggregate_targets: aggregate_targets
      ).run
    end

    def run_spm_post_integrate_hooks
      context = PostIntegrateHooksContext.generate(sandbox, pods_project, pod_target_subprojects, aggregate_targets)
      SPM::Hook::All.new(context).run
    end

    def resolve_spm_dependencies
      # TODO: convert aggregate_targets to umbrella_targets?
      @spm_analyzer ||= Pod::Installer::SPMAnalyzer.new(podfile, aggregate_targets)
      @spm_analyzer.analyze
    end
  end
end
