# Tool utilizes the rake tasks for adding and removing dependents to/from enrollments under a given family.
# This currently builds the arrays for those tasks. See "bulk_remove_family_member_enrollments" and "bulk_add_family_member_enrollments" snippits for those commands
# Next version of this tool will run those commands as well.

def find_person(hbx_id)
  Person.by_hbx_id(hbx_id).first || Person.find_by(hbx_id: hbx_id)
end

#========== Update only these fields ==========#
remove_hix  = _______     # HBX ID of the person remove from enrollments
primary_hix = _______     # HBX ID of the primary subscriber (to locate family)
hix_to_add  = _______     # HBX ID of person to add
#==============================================#

def run_remove_and_print_commands(remove_hix:, primary_hix:, hix_to_add:, dry_run: true)
  # locate primary & family
  primary = find_person(primary_hix)
  family  = primary&.primary_family
  return puts("Primary person or family not found") unless primary && family

  # find persons
  remove_person = find_person(remove_hix)  or (puts "Person with HBX #{remove_hix} not found"; return)
  add_person    = find_person(hix_to_add)  or (puts "Person with HBX #{hix_to_add} not found"; return)

  # family members & enrollments
  fms  = family.family_members.to_a
  enrs = family.hbx_enrollments.to_a

  # family members within THIS family
  remove_fm = fms.find { |m| m.person_id == remove_person.id }
  if remove_fm.nil?
    puts "\e[31mHBX #{remove_person.hbx_id} is NOT a member of family #{family.hbx_assigned_id} (#{family.id})\e[0m"
    return
  end

  add_fm = fms.find { |m| m.person_id == add_person.id }
  if add_fm.nil?
    puts "\e[31mHBX #{add_person.hbx_id} is NOT a member of family #{family.hbx_assigned_id} (#{family.id})\e[0m"
    puts "Add them first (create FamilyMember + CHM/THHM if needed), then re-run."
    return
  end

  # enrollments that include the remove FM
  member_enrs = enrs.select do |e|
    e.hbx_enrollment_members.any? { |m| m.applicant_id.to_s == remove_fm.id.to_s }
  end

  if member_enrs.empty?
    puts "\e[31mHBX #{remove_person.hbx_id}: no enrollments\e[0m"
    return
  end

  # -------- Output 1: array-of-arrays [[enrollment_id, enrollment_member_id], ...] --------
  rows1 = member_enrs.map do |e|
    hem = e.hbx_enrollment_members.detect { |m| m.applicant_id.to_s == remove_fm.id.to_s }
    [e.id.to_s, hem&.id.to_s]
  end

  puts "\e[33mOutput 1 (enrollment_id, enrollment_member_id)\e[0m"
  if rows1.empty?
    puts "[]"
  else
    puts "["
    rows1.each_with_index do |(enr_id, hem_id), i|
      sep = (i == rows1.size - 1 ? "" : ",")
      puts "  ['#{enr_id}','#{hem_id}']#{sep}"
    end
    puts "]"
  end
  puts ""

  # -------- Output 2: array-of-arrays [[enrollment_id, family_member_id, coverage_begin], ...] --------
  rows2 = member_enrs.map do |e|
    coverage_begin = (e.effective_on || e.try(:start_on))
    [e.id.to_s, add_fm.id.to_s, coverage_begin&.strftime("%Y-%m-%d")]
  end

  puts "\e[33mOutput 2 (enrollment_id, family_member_id, coverage_begin)\e[0m"
  if rows2.empty?
    puts "[]"
  else
    puts "["
    rows2.each_with_index do |(enr_id, fm_id, cov_begin), i|
      sep = (i == rows2.size - 1 ? "" : ",")
      puts "  ['#{enr_id}','#{fm_id}','#{cov_begin}']#{sep}"
    end
    puts "]"
  end
  puts ""

  # -------- Optional mutations guarded by dry_run --------
  unless dry_run
    # remove_fm.update!(is_active: false)
    # add_fm.update!(is_active: true)
    puts "\e[32mApplied changes (dry_run: false)\e[0m"
  else
    puts "\e[36mDRY RUN — no changes applied. Set dry_run: false to apply.\e[0m"
  end
end




# Call it
run_remove_and_print_commands(
  remove_hix: remove_hix,
  primary_hix: primary_hix,
  hix_to_add: hix_to_add,
  dry_run: false # set to false to apply mutations in the guarded block
)
