# iOS App Performance Monitoring config

FIREBASE_CONFIG = {
  app_id: ENV['FIREBASE_APP_ID'],
  client_id: ENV['FIREBASE_CLIENT_ID'],
  client_email: ENV['FIREBASE_CLIENT_EMAIL'],
  private_key: ENV['FIREBASE_PRIVATE_KEY']
}

FirebasePerformance.configure do |config|
  config.instrumentMode = .enabled
end

# Set up crash reporting
FirebaseCrashlytics.configure do |config|
  config.debugMode = false
  config.customKeysAndValues = {
    'environment': ENV['ENV'],
    'version': ENV['VERSION_NUMBER'],
    'build': ENV['BUILD_NUMBER']
  }
end

# Add performance monitoring instrumentation
swizzler = FPRMethodSwizzler.init()
swizzler.swizzleInstanceSelector("viewDidAppear:", forClass: UIViewController.self)
swizzler.swizzleInstanceSelector("viewDidDisappear:", forClass: UIViewController.self)
