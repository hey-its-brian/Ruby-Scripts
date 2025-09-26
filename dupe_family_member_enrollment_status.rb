# used to determine which duplicate family members have enrollments and what those are
# can also be used to view enrollment IDs

ids     =  %w[______ _______ _______]
primary =  Person.by_hbx_id(___________).first
family  =  primary&.primary_family
abort "Primary person or family not found" unless primary && family

fms  =  family.family_members.to_a
enrs =  family.hbx_enrollments.to_a

ids.each do |id|
	person = Person.by_hbx_id(id).first
	if person.nil?
		puts "HBX #{id}: person not found"
		next
	end

	fm = fms.find { |m| m.person_id == person.id }
	if fm.nil?
		puts "HBX #{id}: not a member of family #{family.id}"
		next
	end

	member_enrs = enrs.select do |e|
		e.hbx_enrollment_members.any? { |m| m.applicant_id == fm.id }
	end

	if member_enrs.empty?
		puts "HBX #{id}: no enrollments"
	else
		puts "HBX #{id}: on #{member_enrs.size} enrollment(s)"
		member_enrs.each do |e|
			ekey   =  e.hbx_id rescue nil
			state  =  e.aasm_state rescue nil
			kind   =  e.coverage_kind rescue nil
			eff_on =  e.effective_on rescue nil
			puts "  Enrollment #{ekey} state=#{state} kind=#{kind} effective_on=#{eff_on}"
		end
	end
end
