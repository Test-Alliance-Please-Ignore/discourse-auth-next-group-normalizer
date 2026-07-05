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

	def admin_group_names
		SiteSetting.auth_next_group_normalizer_admin_groups
			.to_s
			.split("|")
			.map { |name| normalize_group_name(name) }
			.reject(&:blank?)
			.uniq
	end

	def normalize_associated_group(group)
		source_name = group[:name] || group["name"] || group[:id] || group["id"]
		normalized_name = normalize_group_name(source_name)
		return nil if normalized_name.blank?

		{ id: normalized_name, name: normalized_name }
	end

	def add_synthesized_groups(groups)
		return groups if groups.blank?

		synthesized_group_name = "test-alliance"
		return groups if groups.any? { |group| group[:id] == synthesized_group_name }

		groups + [{ id: synthesized_group_name, name: synthesized_group_name }]
	end

	def sync_identity_from_primary_character(auth_result)
		primary_character_name = auth_result.name.to_s.strip
		return if primary_character_name.blank?

		auth_result.name = primary_character_name
		auth_result.overrides_name = true
		auth_result.username = primary_character_name
		auth_result.overrides_username = true
	end

	def ensure_group_association(provider_name, normalized_name)
		group = Group.find_by(name: normalized_name)
		return unless group

		associated_group =
			begin
				AssociatedGroup.find_or_create_by!(provider_name: provider_name, provider_id: normalized_name) do |record|
					record.name = normalized_name
					record.last_used = Time.zone.now
				end
			rescue ActiveRecord::RecordNotUnique
				retry
			end

		GroupAssociatedGroup.find_or_create_by!(group: group, associated_group: associated_group)
	end

	def grant_admin_if_needed(user, normalized_group_name)
		return if user.blank? || user.admin?
		return unless admin_group_names.include?(normalized_group_name)

		user.update!(admin: true)
	end
end

after_initialize do
	DiscourseEvent.on(:after_auth) do |authenticator, auth_result, _session, _cookies, _request|
		next unless SiteSetting.auth_next_group_normalizer_enabled
		next unless authenticator&.name == "oauth2_basic"
		next if auth_result.blank? || auth_result.failed?

		AuthNextGroupNormalizer.sync_identity_from_primary_character(auth_result)
		next if auth_result.associated_groups.blank?

		provider_name = auth_result.extra_data&.[](:provider) || authenticator.name
		normalized_groups =
			auth_result.associated_groups.filter_map do |group|
				AuthNextGroupNormalizer.normalize_associated_group(group)
			end.uniq { |group| group[:id] }

		normalized_groups = AuthNextGroupNormalizer.add_synthesized_groups(normalized_groups)

		normalized_groups.each do |group|
			AuthNextGroupNormalizer.ensure_group_association(provider_name, group[:id])
			AuthNextGroupNormalizer.grant_admin_if_needed(auth_result.user, group[:id])
		end

		auth_result.associated_groups = normalized_groups
	end

	DiscourseEvent.on(:user_added_to_group) do |user, group, automatic:|
		next unless SiteSetting.auth_next_group_normalizer_enabled
		next unless automatic

		AuthNextGroupNormalizer.grant_admin_if_needed(user, group.name)
	end
end
