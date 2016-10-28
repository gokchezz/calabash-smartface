require 'rspec'
require 'mojo_magick'
require 'pp'

def do_before_scenario
  $case_count = 0
  $error_count = 0
  $start_time = Time.now.strftime('%H:%M:%S')
  $screencap_index = 0
  FileUtils.mkdir_p("screenshots/#{Time.now.strftime('%d%b')}")
  FileUtils.mkdir_p("html_reports")
end

def hide_soft_keyboard
  touch("SpBrPageViewIOS")
end

Then(/^I enter "([^"]*)"$/) do |str|
  touch("SpBrUISingleLineEditBoxIPhone marked:'TextBox'")
  wait_for_keyboard
  keyboard_enter_text(str)
  hide_soft_keyboard
end

Then(/^I enter "([^"]*)" in "([^"]*)" with text "([^"]*)"$/) do |str, class_name, txt|
  touch("#{class_name} marked:'#{txt}'")
  wait_for_keyboard
  keyboard_enter_text(str)
  hide_soft_keyboard
end

Then(/^I enter "([^"]*)" in "([^"]*)" with index (\d+)$/) do |str, class_name, index|
  touch("#{class_name} index:#{index.to_i}")
  wait_for_keyboard
  keyboard_enter_text(str)
  hide_soft_keyboard
end

Then(/^I take control image called "([^"]*)"$/) do |file_name|
  screenshot(options = {:prefix => "control_images", :name => "/#{file_name}.png"})
  File.rename("control_images/#{file_name}_#{$screencap_index}.png", "control_images/#{file_name}.png")
  $screencap_index += 1
end

Then(/^I take a screenshot called "([^"]*)"$/) do |file_name|
  screenshot_embed(options = {:name => "screenshots/#{Time.now.strftime("%d%b")}/#{file_name}.png"})
end

Then(/^I touch "([^"]*)" button$/) do |btn_txt|
  touch("UIButtonLabel marked:'#{btn_txt}'")
end

And(/^I compare location with lat "([^"]*)" and long "([^"]*)"$/) do |lat, long|
  location = query("SPBrUILabeIOS index:0")[0]["text"]
  arr = location.split
  phone_lat = arr[1]
  phone_long = arr[3]
  $case_count += 1
  if (phone_lat[0..5] != lat) || (phone_long[0..5] != long)
    $error_count += 1
    fail("Location did not match with expected result")
  end
end

And(/^I compare screenshot called "([^"]*)"$/) do |file_name|
  screenshot_file = Dir["screenshots/#{Time.now.strftime('%d%b')}/#{file_name}**.png"][0]
  control_file = "control_images/#{file_name}.png"
  compare_result = MojoMagick::execute('compare', %Q[-metric MAE -format "%[distortion]" #{control_file} #{screenshot_file} control_images/NULL])[:error]
  p compare_result
  compare_result = compare_result[/\(.*?\)/]
  compare_result = compare_result[1..compare_result.length-2]
  p compare_result.to_f
  $case_count += 1
  if compare_result.to_f >= 0.00005
    $error_count += 1
    fail("Screenshot comparision throw an error. Comparision result (#{compare_result}) was expected less than 0.00005")
  end
end

And(/^I wait up to (\d+) seconds to see "([^"]*)" button$/) do |time, btn_txt|
  start_time = Time.now
  while true do
    break if Time.now - start_time >= time.to_i
    break if !query("UIButton marked:'#{btn_txt}'").empty?
  end
end

Then(/^I expect not to find any "([^"]*)" with text "([^"]*)"$/) do |class_name, txt|
  expect(query("#{class_name} marked:'#{txt}'").length).to eq(0)
end

Then(/^I touch item with "([^"]*)" id$/) do |id|
  touch("* id:'#{id}'")
end

And(/^I set date to (\d+) "([^"]*)" (\d+)$/) do |day, month, year|
  touch("UIDatePickerContentView marked:'#{day}'")
  touch("UIDatePickerContentView marked:'#{month}'")
  touch("UIDatePickerContentView marked:'#{year}'")
  touch("UIButton marked:'OK'")
end

And(/^I swipe "([^"]*)" on "([^"]*)" with index (\d+)$/) do |direction, class_name, index|
  swipe direction.to_sym, query:"#{class_name} index:#{index}"
end

And(/^I swipe "([^"]*)" (\d+) times on "([^"]*)" with index (\d+)$/) do |direction, n, class_name, index|
    n.to_i.times do
        swipe direction.to_sym, query:"#{class_name} index:#{index}"
    end
end

And(/^I swipe "([^"]*)" on "([^"]*)" with index (\d+) to see "([^"]*)"$/) do |direction, class_name, index, val|
    while true do
        swipe direction.to_sym, query:"#{class_name} index:#{index}"
        break if !query("#{class_name} marked:'#{val}'").empty?
    end
end

And(/^I touch (\d+) times on "([^"]*)" with index (\d+)$/) do |nn, class_name, index|
  nn.to_i.times do
    touch("#{class_name} index:#{index}")
  end
end

And(/^I wait up to (\d+) seconds to see "([^"]*)" with text "([^"]*)"/) do |time, class_name, txt|
  start_time = Time.now
  while true do
    break if Time.now - start_time >= time.to_i
    break if !query("* #{class_name} marked:'#{txt}'").empty?
  end
end

And(/^I pinch to zoom "([^"]*)" on "([^"]*)"$/) do |direction, class_name|
  pinch direction.to_sym, query:"#{class_name}" #todo bu metod calismadi tekrar yazilcak
end

Given(/^I wait upto (\d+) seconds for application to start$/) do |sec|
  start_time = Time.now
  while true do
    break if Time.now - start_time >= sec.to_i
    break if !query("SpBrPageViewIOS").empty?
  end
end

