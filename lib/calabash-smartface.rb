require 'make_report'

def save_report_on_azure(reference_path, screenshot_path, test_name, result_path, device_name)
  prepare_report(reference_path, screenshot_path, test_name, $errors, result_path, device_name)
end

And(/^I wait (\d+) seconds$/) do |number|
  sleep number.to_i
end

Then(/^I touch "([^"]*)" with index (\d+)$/) do |class_name, index|
  begin
    touch(query("#{class_name} index:#{index}"))
  rescue Exception => e
    p "No #{class_name} with index:#{index}"
  end
end

And(/^I touch "([^"]*)" or "([^"]*)" or "([^"]*)" button$/) do |x, y, z|
  touch("* marked:'#{x}'") if !query("* marked:'#{x}'").empty?
  touch("* marked:'#{y}'") if !query("* marked:'#{y}'").empty?
  touch("* marked:'#{z}'") if !query("* marked:'#{z}'").empty?
end

Then(/^I touch any button with text "([^"]*)"$/) do |btn_txt|
  begin
    touch("* marked:'#{btn_txt}'")
  rescue Exception => e
    p "No * marked:#{btn_txt}"
  end
end

And(/^I long press "([^"]*)" button$/) do |btn_txt|
  long_press("SpButton marked:'#{btn_txt}'")
end

And(/^I touch "([^"]*)" with text "([^"]*)"$/) do |class_name, txt|
  begin
    touch(query("* #{class_name} marked:'#{txt}'"))
  rescue Exception => e
    p "No #{class_name} marked:#{txt}"
  end
end

And(/^I long press "([^"]*)" with text "([^"]*)"$/) do |class_name, txt|
  long_press(query("* #{class_name} marked:'#{txt}'"),:time => 10)
end

Then(/^I perform "([^"]*)" from (\d+) (\d+) to (\d+) (\d+)$/) do |type, fromX, fromY, toX,toY|
  perform_action("#{type}",fromX.to_i,toX.to_i, fromY.to_i,toY.to_i,1)
end

And(/^I pinch "([^"]*)" on "([^"]*)" with index (\d+)$/) do |direction, class_name, index|
  pinch("#{class_name} index:#{index.to_i}", direction.to_sym )
end