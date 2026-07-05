# frozen_string_literal: true

# name: auth-next-group-normalizer
# about: Normalizes Auth Next OAuth2 Basic group names for Discourse group sync
# version: 0.1
# authors: OpenAI

enabled_site_setting :auth_next_group_normalizer_enabled

module ::AuthNextGroupNormalizer
	module_function

	def normalize_group_name(name)
		name.to_s.strip.downcase.gsub(/\s+/, "-").gsub(/-+/, "-")
	end

	def normalize_associated_group(group)
		source_name = group[:name] || group["name"] || group[:id] || group["id"]
		normalized_name = normalize_group_name(source_name)
		return nil if normalized_name.blank?

		{ id: normalized_name, name: normalized_name }
	end
end

after_initialize do
	DiscourseEvent.on(:after_auth) do |authenticator, auth_result, _session, _cookies, _request|
		next unless SiteSetting.auth_next_group_normalizer_enabled
		next unless authenticator&.name == "oauth2_basic"
		next if auth_result.blank? || auth_result.failed?
		next if auth_result.associated_groups.blank?

		auth_result.associated_groups =
			auth_result.associated_groups.filter_map do |group|
				AuthNextGroupNormalizer.normalize_associated_group(group)
			end.uniq
	end
end
