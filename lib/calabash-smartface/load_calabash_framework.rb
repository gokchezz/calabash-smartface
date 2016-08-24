pbx_file = Dir["Smartface.xcodeproj/project.pbxproj"][0]

linker_flag1 = %q["-force_load",]
linker_flag2 = %q["\"$(SOURCE_ROOT)/calabash.framework/calabash\"",]
provisioning_profile = '497e9788-936d-45b3-815f-0d2a694abfe4'

new_content = ""
do_change = true

out_file = File.open(pbx_file, 'r')
out_file.each_line do |line|
  if line.include? "calabash.framework"
    do_change = false
  end
end
out_file.close

p "do_change = #{do_change}"

if do_change
  out_file = File.open(pbx_file, 'r')
  out_file.each_line do |line|
    if line.include? %q[-liconv",]
      line = line + linker_flag1
      line = line + linker_flag2
      p line
    end
    # if line.include? 'PROVISIONING_PROFILE = "'
    #   line = line + provisioning_profile
    #   p line
    # end
    # if line.include? 'PROVISIONING_PROFILE[sdk=iphoneos*]" = "'
    #   line = line + provisioning_profile
    #   p line
    # end
    new_content += line
  end
  out_file.close

  new_file = File.new "newproject.pbxproj", 'w'
  File.open(new_file, "w") do |f|
    f.write(new_content)
  end
  new_file.close
  File.delete(pbx_file)
  File.rename("newproject.pbxproj", "Smartface.xcodeproj/project.pbxproj")
end



