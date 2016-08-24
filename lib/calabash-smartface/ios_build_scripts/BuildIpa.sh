xcodebuild archive -project Smartface.xcodeproj -scheme SmartfaceDemo -archivePath Smartface.xcarchive
xcodebuild -exportArchive -archivePath Smartface.xcarchive -exportPath Smartface -exportFormat ipa -exportProvisioningProfile "smf-inhouse"
