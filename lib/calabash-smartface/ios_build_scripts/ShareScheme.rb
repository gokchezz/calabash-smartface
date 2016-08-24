#!/usr/bin/env ruby
#http://mgrebenets.github.io/xcode/2014/05/29/share-xcode-schemes/
require 'xcodeproj'
xcproj = Xcodeproj::Project.open("Smartface.xcodeproj")
xcproj.recreate_user_schemes
xcproj.save