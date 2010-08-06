// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "chrome/browser/browser_main.h"

#import <Cocoa/Cocoa.h>

#include "app/app_switches.h"
#include "app/l10n_util_mac.h"
#include "app/resource_bundle.h"
#include "base/command_line.h"
#include "base/debug_util.h"
#include "base/file_path.h"
#include "base/mac_util.h"
#include "base/path_service.h"
#include "base/scoped_nsobject.h"
#include "chrome/app/breakpad_mac.h"
#import "chrome/browser/app_controller_mac.h"
#include "chrome/browser/browser_main_win.h"
#import "chrome/browser/chrome_browser_application_mac.h"
#import "chrome/browser/cocoa/keystone_glue.h"
#include "chrome/browser/metrics/metrics_service.h"
#include "chrome/common/chrome_paths.h"
#include "chrome/common/main_function_params.h"
#include "chrome/common/notification_service.h"
#include "chrome/common/result_codes.h"

// Tell Cooca to finish its initalization, which we want to do manually
// instead of calling NSApplicationMain(). The primary reason is that NSAM()
// never returns, which would leave all the objects currently on the stack
// in scoped_ptrs hanging and never cleaned up. We then load the main nib
// directly. The main event loop is run from common code using the
// MessageLoop API, which works out ok for us because it's a wrapper around
// CFRunLoop.
void WillInitializeMainMessageLoop(const MainFunctionParams& parameters) {
  // Initialize NSApplication using the custom subclass.
  [BrowserCrApplication sharedApplication];

  // If ui_task is not NULL, the app is actually a browser_test, so startup is
  // handled outside of BrowserMain (which is what called this).
  if (!parameters.ui_task) {
    // The browser process only wants to support the language Cocoa will use, so
    // force the app locale to be overriden with that value.
    l10n_util::OverrideLocaleWithCocoaLocale();

    // Before we load the nib, we need to start up the resource bundle so we
    // have the strings avaiable for localization.
    std::wstring pref_locale;
    // TODO(markusheintz): Read preference pref::kApplicationLocale in order to
    // enforce the application locale.
    ResourceBundle::InitSharedInstance(pref_locale);

    FilePath resources_pack_path;
    PathService::Get(chrome::FILE_RESOURCES_PACK, &resources_pack_path);
    ResourceBundle::AddDataPackToSharedInstance(resources_pack_path);
  }

  // Now load the nib (from the right bundle).
  scoped_nsobject<NSNib>
      nib([[NSNib alloc] initWithNibNamed:@"MainMenu"
                                   bundle:mac_util::MainAppBundle()]);
  [nib instantiateNibWithOwner:NSApp topLevelObjects:nil];
  // Make sure the app controller has been created.
  DCHECK([NSApp delegate]);

  // This is a no-op if the KeystoneRegistration framework is not present.
  // The framework is only distributed with branded Google Chrome builds.
  [[KeystoneGlue defaultKeystoneGlue] registerWithKeystone];

  // Prevent Cocoa from turning command-line arguments into
  // |-application:openFiles:|, since we already handle them directly.
  [[NSUserDefaults standardUserDefaults]
      setObject:@"NO" forKey:@"NSTreatUnknownArgumentsAsOpen"];
}

void DidEndMainMessageLoop() {
  AppController* appController = [NSApp delegate];
  [appController didEndMainMessageLoop];
}

void RecordBreakpadStatusUMA(MetricsService* metrics) {
  metrics->RecordBreakpadRegistration(IsCrashReporterEnabled());
  metrics->RecordBreakpadHasDebugger(DebugUtil::BeingDebugged());
}

void WarnAboutMinimumSystemRequirements() {
  // Nothing to check for on Mac right now.
}

// From browser_main_win.h, stubs until we figure out the right thing...

int DoUninstallTasks(bool chrome_still_running) {
  return ResultCodes::NORMAL_EXIT;
}

int HandleIconsCommands(const CommandLine& parsed_command_line) {
  return 0;
}

bool CheckMachineLevelInstall() {
  return false;
}

void PrepareRestartOnCrashEnviroment(const CommandLine& parsed_command_line) {
}