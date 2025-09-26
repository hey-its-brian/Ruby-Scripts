# script looks at system and finds all instances of duplicate family members with the same person ID but different FM IDs

# frozen_string_literal: true

require 'csv'
require 'set'

# ------------ settings ------------
dry_run = false   # set to false to actually remove
timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
Dir.mkdir("tmp") unless File.exist?("tmp")
Dir.mkdir("tmp/hbx_reports") unless File.exist?("tmp/hbx_reports")

removed_csv  = File.join(Dir.pwd, "tmp/hbx_reports/duplicate_fm_removed_#{timestamp}.csv")
skipped_csv  = File.join(Dir.pwd, "tmp/hbx_reports/duplicate_fm_NOT_removed_#{timestamp}.csv")

# ------------ counters ------------
total_fams      = 0
dupe_groups     = 0
skipped_groups  = 0
removed_fms     = 0
removed_chms    = 0
removed_thhms   = 0
skipped_fms     = 0  # new: FMs skipped due to FA guard

# ------------ CSV accumulators ------------
removed_rows = []  # one row per removed FM
skipped_rows = []  # one row per skipped dupe group or FM (reason differentiates)

# ------------ helper: ever enrolled within this family? ------------
def fm_ever_enrolled_in_family?(family_id, fm_id)
	HbxEnrollment.where(
		:family_id => family_id,
		'hbx_enrollment_members.applicant_id' => { '$in' => [fm_id, fm_id.to_s] }
	).exists?
end

# ------------ FA helpers ------------
def fa_applicant_hbx_ids_for_family(family)
	apps = FinancialAssistance::Application.where(family_id: family.id)
	hbx_set = Set.new
	apps.each do |app|
		app.applicants.to_a.each do |appl|
			h = appl.respond_to?(:person_hbx_id) ? appl.person_hbx_id : nil
			h = h.to_s
			hbx_set << h unless h.empty?
		end
	end
	hbx_set
end

# ------------ main ------------
families = Family.where(:'family_members.1'.exists => true).no_timeout
total_fams = families.count
puts "[INFO] Scanning #{total_fams} families for duplicate family members by person_id..."

families.each_with_index do |family, idx|
	grouped = family.family_members.group_by(&:person_id)
	dupes   = grouped.select { |_pid, members| members.size > 1 }
	next if dupes.empty?

	# preload FA applicant HBX IDs for this family
	fa_hbx_ids = fa_applicant_hbx_ids_for_family(family)

	puts "\n============================================================="
	puts "[#{idx+1}/#{total_fams}] Family HBX=#{family.hbx_assigned_id} _id=#{family.id}"
	dupes.each do |pid, members|
		dupe_groups += 1

		# Determine enrollment history per FM
		enrolled_map = {}
		members.each do |fm|
			enrolled_map[fm.id.to_s] = fm_ever_enrolled_in_family?(family.id, fm.id)
		end
		enrolled_fms = members.select { |fm| enrolled_map[fm.id.to_s] }

		keeper = nil
		to_remove = []

		if enrolled_fms.size == 0
			# keep earliest; remove others
			keeper = members.min_by(&:created_at)
			to_remove = members - [keeper]
			reason = "none_enrolled_keep_earliest"
		elsif enrolled_fms.size == 1
			# keep the one with enrollments; remove others
			keeper = enrolled_fms.first
			to_remove = members - [keeper]
			reason = "one_enrolled_keep_enrolled"
		else
			# 2+ enrolled → skip whole duplicate set
			skipped_groups += 1
			skipped_rows << {
				family_hbx_id: family.hbx_assigned_id,
				family_id:     family.id.to_s,
				person_id:     pid.to_s,
				dupe_fm_ids:   members.map { |m| m.id.to_s }.join(";"),
				enrolled_fm_ids: enrolled_fms.map { |m| m.id.to_s }.join(";"),
				reason:        "multiple_enrolled_skip"
			}
			puts "  \e[33mSKIP person_id=#{pid} — multiple dupes have enrollments\e[0m (#{enrolled_fms.map(&:id).join(', ')})"
			next
		end

		# Execute removals for each FM in to_remove (with FA guard)
		to_remove.each do |fm|
			fm_id_s = fm.id.to_s

			# --- FA guard: skip if this FM's person HBX ID is in any FA application for the family ---
			fm_phbx = fm.try(:person).try(:hbx_id).to_s
			if !fm_phbx.empty? && fa_hbx_ids.include?(fm_phbx)
				skipped_fms += 1
				skipped_rows << {
					family_hbx_id: family.hbx_assigned_id,
					family_id:     family.id.to_s,
					person_id:     pid.to_s,
					dupe_fm_ids:   members.map { |m| m.id.to_s }.join(";"),
					enrolled_fm_ids: enrolled_fms.map { |m| m.id.to_s }.join(";"),
					reason:        "fa_applicant_exists(person_hbx_id=#{fm_phbx}; fm_id=#{fm_id_s})"
				}
				puts "  \e[33mSKIP FM #{fm_id_s}\e[0m — FA applicant exists (person_hbx_id=#{fm_phbx})"
				next
			end
			# ------------------------------------------------------------------------------------------

			chm_removed_for_fm  = 0
			thhm_removed_for_fm = 0

			# Remove CHMs
			family.households.each do |hh|
				hh.coverage_households.each do |chh|
					chh.coverage_household_members.to_a.each do |chm|
						next unless chm.family_member_id.to_s == fm_id_s
						if dry_run
							puts "  DRY-RUN: would remove CHM #{chm.id} (coverage_household_id=#{chh.id})"
						else
							chm.destroy
						end
						chm_removed_for_fm += 1
						removed_chms += 1
					end
				end
			end

			# Remove THHMs — handle common field names
			family.households.each do |hh|
				hh.tax_households.each do |thh|
					thh.tax_household_members.to_a.each do |thhm|
						next unless (thhm.respond_to?(:applicant_id) && thhm.applicant_id.to_s == fm_id_s) ||
							(thhm.respond_to?(:family_member_id) && thhm.family_member_id.to_s == fm_id_s)
						if dry_run
							puts "  DRY-RUN: would remove THHM #{thhm.id} (tax_household_id=#{thh.id})"
						else
							thhm.destroy
						end
						thhm_removed_for_fm += 1
						removed_thhms += 1
					end
				end
			end

			# Remove FM
			if dry_run
				puts "  DRY-RUN: would destroy FamilyMember #{fm.id}"
			else
				fm.destroy
			end
			removed_fms += 1

			# Add a row per removed FM
			removed_rows << {
				family_hbx_id:          family.hbx_assigned_id,
				family_id:              family.id.to_s,
				person_id:              pid.to_s,
				kept_family_member_id:  keeper.id.to_s,
				removed_family_member_id: fm_id_s,
				reason:                 reason,
				removed_chm_count:      chm_removed_for_fm,
				removed_thhm_count:     thhm_removed_for_fm,
				dry_run:                dry_run
			}
		end
	end
end

# ------------ write CSVs ------------
CSV.open(skipped_csv, "w") do |csv|
	csv << %w[
		family_hbx_id
		family_id
		person_id
		dupe_fm_ids
		enrolled_fm_ids
		reason
	]
	skipped_rows.each do |r|
		csv << [
			r[:family_hbx_id],
			r[:family_id],
			r[:person_id],
			r[:dupe_fm_ids],
			r[:enrolled_fm_ids],
			r[:reason]
		]
	end
end

CSV.open(removed_csv, "w") do |csv|
	csv << %w[
		family_hbx_id
		family_id
		person_id
		kept_family_member_id
		removed_family_member_id
		reason
		removed_chm_count
		removed_thhm_count
		dry_run
	]
	removed_rows.each do |r|
		csv << [
			r[:family_hbx_id],
			r[:family_id],
			r[:person_id],
			r[:kept_family_member_id],
			r[:removed_family_member_id],
			r[:reason],
			r[:removed_chm_count],
			r[:removed_thhm_count],
			r[:dry_run]
		]
	end
end

# ------------ summary ------------
puts "\n======================== Summary ========================"
puts "Families scanned (with >1 FM):   #{total_fams}"
puts "Duplicate groups found:          #{dupe_groups}"
puts "Groups skipped (>=2 enrolled):   #{skipped_groups}"
puts "FamilyMembers skipped (FA):      #{skipped_fms}"
puts "FamilyMembers removed:           #{removed_fms} #{dry_run ? '(DRY-RUN)' : ''}"
puts "CHMs removed:                    #{removed_chms} #{dry_run ? '(DRY-RUN)' : ''}"
puts "THHMs removed:                   #{removed_thhms} #{dry_run ? '(DRY-RUN)' : ''}"
puts "Removed CSV:                     #{removed_csv}"
puts "Not-removed CSV:                 #{skipped_csv}"
puts "Mode:                            #{dry_run ? 'DRY-RUN (no changes made)' : 'APPLIED (changes committed)'}"
puts "========================================================="
