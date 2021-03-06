require 'rspec'
require 'mojo_magick'
require 'ADB'
require 'pp'
require 'save_results'

include ADB

def append_date(name)
  (name +'_'+ Time.now.strftime('%d%b').strip)
end

def get_device(serial)
  $devices.each do |device|
    if device[:serial].to_i == serial.to_i
      return device
    end
  end
end

def increase_error_count(test_name)
  $errors << test_name
end

def get_error_count
  $errors.length
end

def get_errors
  $errors
end

def increase_case_count
  $case_count += 1
end

def do_before_scenario
  $case_count = 0
  $errors = []
  $start_time = Time.now.strftime('%H:%M:%S')
  $devices = []
  sn = ADB.devices
  sn.each do |serial|
    ADB.shell("getprop ro.product.model", {:serial => serial}, 30)
    model = (ADB.last_stdout.strip).tr(' ','_')
    $devices << {:serial => serial, :model => model}
    FileUtils.mkdir_p("screenshots/#{Time.now.strftime('%d%b')}/#{serial}_#{model}")
    FileUtils.mkdir_p('html_reports')
    FileUtils.mkdir_p("control_images/#{model}")
  end
end

def do_after_scenario
  p "#{$case_count} cases run totally"
  $errors.each do |error|
    p error
  end
  p "Test ended with #{$errors.length} error(s)"
  raise "Test ended with #{$errors.length} error(s)" if $errors.length > 0
end

def do_crop_on_screenshot(device, screenshot_file)
  if $do_crop
    case device[:model]
      when "SM-T210R"
        crop = 3
      when "Nexus_6"
        crop = 3
      when "SGH-M919"
        crop = 4
      when "GT-I9300"
        crop = 4
      when "LG-D802"
        crop = 4
      when "GT-I9190"
        crop = 4
      else
        crop = 3
    end
    MojoMagick::raw_command('convert', "#{screenshot_file} -chop 0x#{crop}% #{screenshot_file}")
  end
end

def save_results_to_file(root_path, test_name)
  device = get_device(ENV["ADB_DEVICE_ARG"])
  version = get_os_version
  device_name = "#{device[:model]} - Android v.#{version} - #{test_name}"
  report_file = "https://smartfacecdn.blob.core.windows.net/test-automation/#{Time.now.strftime('%d-%m-%y')}/#{test_name}%20on%20#{device[:model]}.html"
  save_results_on_existing_file(root_path, device_name, $case_count, $start_time, $errors, "#{report_file}")
  return device_name
end

def get_os_version
  output = `#{default_device.adb_command} shell getprop ro.build.version.release`
  return output.strip
end

Given(/^I wait upto (\d+) seconds for the app to start$/) do |sec|
  start_time = Time.now
  while true do
    break if Time.now - start_time >= sec.to_i
    break if !query('SpPage').empty?
  end
end

And(/^I wait upto (\d+) seconds for "([^"]*)" to appear$/) do |sec, class_name|
  start_time = Time.now
  while true do
    break if Time.now - start_time >= sec.to_i
    break if !query("#{class_name}").empty?
    break if !query("* marked:'#{class_name}'").empty?
    break if !query("* id:'#{class_name}'").empty?
  end
end

Then (/^I enter ([^"]*)$/) do |str|
  clear_text_in("SpEditText")
  enter_text("SpEditText", str.tr('"', ''))
  hide_soft_keyboard
end

And(/^I touch "([^"]*)" button$/) do |btn_txt|
  begin
    touch("SpButton marked:'#{btn_txt}'")
  rescue Exception => e
    p "No button marked:#{btn_txt}"
  end
end

And(/^I wait up to (\d+) seconds to see "([^"]*)" button$/) do |time, btn_txt|
  start_time = Time.now
  while true do
    break if Time.now - start_time >= time.to_i
    break if !query("* SpButton marked:'#{btn_txt}'").empty?
  end
end

Then(/^I wait (\d+) seconds to see "([^"]*)" text$/) do |time, txt|
  start_time = Time.now
  while true do
    if Time.now - start_time <= time.to_i
      break if !query("AppCompatTextView marked:'#{txt}'").empty?
    else
      fail("#{txt} Element could not found")
    end
  end
end

Then(/^I press "([^"]*)" button (\d+) times and compare screenshots$/) do |btn_txt, n|
  i = 1
  device = get_device(ENV["ADB_DEVICE_ARG"])
  n.to_i.times do
    touch(query("* SpButton marked:'#{btn_txt}'"))
    sleep 0.5
    screenshot_embed({:name => "#{device[:model]}/#{btn_txt}#{append_date("_button_pressed")}"})
    control_file = "control_images/#{device[:model]}/#{btn_txt}_button_pressed_#{i}.png"
    screenshot_file = "screenshots/#{Time.now.strftime('%d%b')}/#{device[:serial]}_#{device[:model]}/#{btn_txt}#{append_date("_button_pressed")}_#{i}.png"
    do_crop_on_screenshot(device, screenshot_file)
    compare_result = MojoMagick::execute('compare', %Q[-metric MAE -format "%[distortion]" #{control_file} #{screenshot_file} control_images/NULL])[:error]
    compare_result = compare_result[/\(.*?\)/]
    compare_result = compare_result[1..compare_result.length-2]
    if compare_result.to_f >= 0.00005
      $errors << "#{btn_txt}_button_pressed_#{i}"
      p("Screenshot comparision fails on '#{btn_txt}' at #{i}th press. Comparision result (#{compare_result}) was expected less than 0.00005")
    end
    i += 1
  end
end

Then(/^I press "([^"]*)" with index (\d+), (\d+) times and compare screenshots called "([^"]*)"$/) do |class_name, index, n, file_name|
  i = 0
  device = get_device(ENV["ADB_DEVICE_ARG"])
  n.to_i.times do
    touch(query("#{class_name} index:#{index}"))
    sleep 0.5
    screenshot_name = "#{file_name}#{i}"
    screenshot_embed({:name => "#{device[:model]}/#{append_date(screenshot_name)}"})
    control_file = "control_images/#{device[:model]}/#{screenshot_name}.png"
    files = Dir["screenshots/#{Time.now.strftime('%d%b')}/#{device[:serial]}_#{device[:model]}/#{append_date(screenshot_name)}**.png"]
    do_crop_on_screenshot(device, files[0])
    compare_result = MojoMagick::execute('compare', %Q[-metric MAE -format "%[distortion]" #{control_file} #{files[0]} control_images/NULL])[:error]
    compare_result = compare_result[/\(.*?\)/]
    compare_result = compare_result[1..compare_result.length-2]
    if compare_result.to_f >= 0.00005
      $errors << screenshot_name
      p("Screenshot comparision fails on '#{file_name}' at #{i}th press. Comparision result (#{compare_result}) was expected less than 0.00005")
    end
    i += 1
  end
end

Then(/^I press "([^"]*)" with index (\d+), (\d+) times and I take control images called "([^"]*)"$/) do |class_name, index, n, img_name|
  i = 0
  device = get_device(ENV["ADB_DEVICE_ARG"])
  n.to_i.times do
    touch(query("#{class_name} index:#{index.to_i}"))
    sleep 0.5
    screenshot({:name => "#{device[:model]}/#{append_date(img_name)}_#{i}"})
    screenshot_file = Dir["screenshots/#{Time.now.strftime('%d%b')}/#{device[:serial]}_#{device[:model]}/#{append_date(img_name)}_#{i}**.png"][0]
    control_file = "control_images/#{device[:model]}/#{img_name}#{i}.png"
    File.rename(screenshot_file, control_file)
    do_crop_on_screenshot(device, control_file)
    i += 1
  end
end


And(/^I take a screenshot called "([^"]*)"$/) do |file_name|
  device = get_device(ENV["ADB_DEVICE_ARG"])
  screenshot_embed({:name => "#{device[:model]}/#{file_name}_#{Time.now.strftime('%d%b')}"})
  screenshot_file = Dir["screenshots/#{Time.now.strftime('%d%b')}/#{device[:serial]}_#{device[:model]}/#{file_name}**.png"][0]
  do_crop_on_screenshot(device, screenshot_file)
end

And(/^I compare screenshot called "([^"]*)"$/) do |file_name|
  device = get_device(ENV["ADB_DEVICE_ARG"])
  screenshot_file = Dir["screenshots/#{Time.now.strftime('%d%b')}/#{device[:serial]}_#{device[:model]}/#{file_name}**.png"][0]
  control_file = "control_images/#{device[:model]}/#{file_name}.png"
  compare_result = MojoMagick::execute('compare', %Q[-metric MAE -format "%[distortion]" #{control_file} #{screenshot_file} control_images/NULL])[:error]
  if compare_result[/\(.*?\)/].nil?
    $errors << file_name
    p compare_result
  else
    compare_result = compare_result[/\(.*?\)/]
    compare_result = compare_result[1..compare_result.length-2]
    if compare_result.to_f >= 0.00005
      $errors << file_name
      p("Screenshot comparision fails on '#{file_name}'. Comparision result (#{compare_result}) was expected less than 0.00005")
    end
  end
  $case_count += 1
end

And(/^I hide keyboard$/) do
  hide_soft_keyboard
end

Then(/^I enter "([^"]*)" in "([^"]*)" with index (\d+)$/) do |str, class_name, index|
  enter_text("* #{class_name} index:#{index.to_i}", str.tr('"', ''))
  hide_soft_keyboard
end

Then(/^I enter "([^"]*)" in "([^"]*)" with text "([^"]*)"$/) do |str, class_name, txt|
  enter_text("#{class_name} marked:'#{txt}'", str.tr('"', ''))
  hide_soft_keyboard
end

Then(/^I take control image called "([^"]*)"$/) do |file_name|
  device = get_device(ENV["ADB_DEVICE_ARG"])
  screenshot({:name => "#{device[:model]}/#{append_date(file_name)}"})
  screenshot_file = Dir["screenshots/#{Time.now.strftime('%d%b')}/#{device[:serial]}_#{device[:model]}/#{file_name}**.png"][0]
  control_file = "control_images/#{device[:model]}/#{file_name}.png"
  File.rename(screenshot_file, control_file)
  do_crop_on_screenshot(device, control_file)
end

Then(/^I send shell command "([^"]*)"$/) do |command|
  system("#{default_device.adb_command} shell #{command}")
end

Then(/^I set date to (\d+) (\d+) (\d+)$/) do |year, month, day|
  query("DatePicker index:0", :method_name => 'updateDate', :arguments => [year.to_i,month.to_i-1,day.to_i])
end

Then(/^I send shell command "([^"]*)" for snapshot button$/) do |command|
  device = get_device(ENV["ADB_DEVICE_ARG"])
  x = ""
  y = ""
  case device[:model]
    when "Nexus_6"
      x = "723"
      y = "2158"
    when "SGH-M919"
      x = "1790"
      y = "545"
    when "LG-D802"
      x = "540"
      y = "1695"
  end
  command = "#{command} #{x} #{y}"
  system("#{default_device.adb_command} shell #{command}")
end

Then(/^I send shell command "([^"]*)" to save snapshot$/) do |command|
  device = get_device(ENV["ADB_DEVICE_ARG"])
  x = ""
  y = ""
  case device[:model]
    when "Nexus_6"
      x = "723"
      y = "2158"
    when "SGH-M919"
      x = "800"
      y = "1845"
    when "LG-D802"
      x = "780"
      y = "1720"
  end
  command = "#{command} #{x} #{y}"
  system("#{default_device.adb_command} shell #{command}")
end

And(/^I compare location with lat "([^"]*)" and long "([^"]*)"$/) do |lat, long|
  location = query("AutoFontSizeTextView index:0")[0]["text"]
  arr = location.split
  phone_lat = arr[1]
  phone_long = arr[3]
  expect(phone_lat[0..5]).to eq lat
  expect(phone_long[0..5]).to eq long
  $case_count += 1
end

Then(/^I press "([^"]*)" button value of "([^"]*)" times and I take control images$/) do |btn_txt, element|
  n = query("#{element}", :text)[0]
  i = 1
  device = get_device(ENV["ADB_DEVICE_ARG"])
  n.to_i.times do
    touch(query("* SpButton marked:'#{btn_txt}'"))
    sleep 0.5
    screenshot({:name => "#{device[:model]}/#{btn_txt}#{append_date("_button_pressed")}_#{i}"})
    screenshot_file = Dir["screenshots/#{Time.now.strftime('%d%b')}/#{device[:serial]}_#{device[:model]}/#{btn_txt}#{append_date("_button_pressed")}_#{i}**.png"][0]
    control_file = "control_images/#{device[:model]}/#{btn_txt}_button_pressed_#{i}.png"
    File.rename(screenshot_file, control_file)
    do_crop_on_screenshot(device, control_file)
    i += 1
  end
end

Then(/^I press "([^"]*)" button value of "([^"]*)" times and I compare screenshots$/) do |btn_txt, element|
  n = query("#{element}", :text)[0]
  i = 1
  device = get_device(ENV["ADB_DEVICE_ARG"])
  n.to_i.times do
    touch(query("* SpButton marked:'#{btn_txt}'"))
    sleep 0.5
    screenshot_embed({:name => "#{device[:model]}/#{btn_txt}#{append_date("_button_pressed")}_#{i}"})
    control_file = "control_images/#{device[:model]}/#{btn_txt}_button_pressed_#{i}.png"
    screenshot_file = Dir["screenshots/#{Time.now.strftime('%d%b')}/#{device[:serial]}_#{device[:model]}/#{btn_txt}#{append_date("_button_pressed")}_#{i}**.png"][0]
    do_crop_on_screenshot(device, screenshot_file)
    compare_result = MojoMagick::execute('compare', %Q[-metric MAE -format "%[distortion]" #{control_file} #{screenshot_file} control_images/NULL])[:error]
    compare_result = compare_result[/\(.*?\)/]
    compare_result = compare_result[1..compare_result.length-2]
    if compare_result.to_f >= 0.00005
      $errors << "#{btn_txt}_button_pressed_#{i}"
      p("Screenshot comparision fails on '#{btn_txt}' at #{i}th press. Comparision result (#{compare_result}) was expected less than 0.00005")
    end
    i += 1
    $case_count += 1
  end
end

When(/^I scroll up "([^"]*)" text in page$/) do |txt|
  pan("* marked:'#{txt}'", :up, {:y => 100})
end

When(/^I scroll down "([^"]*)" text in page$/) do |txt|
  pan("* marked:'#{txt}'", :down, {:y => -100})
end