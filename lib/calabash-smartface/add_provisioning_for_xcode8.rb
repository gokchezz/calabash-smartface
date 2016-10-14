pbx_file = Dir["Smartface.xcodeproj/project.pbxproj"][0]
#require 'pp'
#pbx_file = Dir["project.pbxproj"][0]

team_var = 'T9P2R7YH4K'
prov_var = %q[ProvisioningStyle = Automatic;]
bundle_name = ARGV[0]

new_content = ''
do_change = true
specifier_index = 0

out_file = File.open(pbx_file, 'r')
out_file.each_line do |line|
  if line.include? "DevelopmentTeam = T9P2R7YH4K;"
    do_change = false
  end
end
out_file.close

p "do_change = #{do_change}"

if do_change
  out_file = File.open(pbx_file, 'r')
  out_file.each_line do |line|
    if line.include? %q[ProvisioningStyle = ]
      line = "\t\t\t\t\t\tDevelopmentTeam = #{team_var};\n"
      #line = "#{line}\t\t\t\t\t\t#{prov_var}\n"
      p line
    end
    if line.include? %q[DEVELOPMENT_TEAM = "";]
      line = "\t\t\t\tDEVELOPMENT_TEAM = #{team_var};\n"
      p line
    end
    # if line.include? %q[Smartface-Demo.app]
    #   line = line.gsub('Smartface-Demo', bundle_name)
    #   p line
    # end
    # if line.include? %q["PROVISIONING_PROFILE[sdk=iphoneos*]" = "";]
    #   specifier_index += 1
    #   if specifier_index == 3
    #     line = "#{line}\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "";\n"
    #     p line
    #   end
    # end
    new_content += line
  end
  out_file.close

  #pp new_content

  new_file = File.new "newproject.pbxproj", 'w'
  File.open(new_file, "w") do |f|
    f.write(new_content)
  end
  new_file.close
  File.delete(pbx_file)
  File.rename("newproject.pbxproj", "Smartface.xcodeproj/project.pbxproj")
  #File.rename('newproject.pbxproj', 'project.pbxproj')
end



