#!/usr/bin/env python3
"""Regenerate SereneDriving.xcodeproj from whatever is inside SereneDriving/.

Run it after adding or removing a source file:
    python3 gen_pbxproj.py
"""
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
TARGET = "SereneDriving"
BUNDLE_ID = "com.lno.serenedriving"
SRC_DIR = os.path.join(ROOT, TARGET)
PROJ_DIR = os.path.join(ROOT, TARGET + ".xcodeproj")

_counter = [0]


def uid():
    _counter[0] += 1
    return "AA%022X" % _counter[0]


swift_files = sorted(f for f in os.listdir(SRC_DIR) if f.endswith(".swift"))
resources = ["Assets.xcassets"]
if os.path.exists(os.path.join(SRC_DIR, "PrivacyInfo.xcprivacy")):
    resources.append("PrivacyInfo.xcprivacy")

refs = {}       # name -> file ref id
build = {}      # name -> build file id
for name in swift_files + resources + ["Info.plist"]:
    refs[name] = uid()
for name in swift_files + resources:
    build[name] = uid()

PRODUCT_REF = uid()
MAIN_GROUP = uid()
SRC_GROUP = uid()
PRODUCTS_GROUP = uid()
TARGET_ID = uid()
PROJECT_ID = uid()
SOURCES_PHASE = uid()
FRAMEWORKS_PHASE = uid()
RESOURCES_PHASE = uid()
PROJ_CONF_LIST = uid()
TARGET_CONF_LIST = uid()
PROJ_DEBUG = uid()
PROJ_RELEASE = uid()
TARGET_DEBUG = uid()
TARGET_RELEASE = uid()
# OneSignal (Crazy Bee Labs announcements), vendoré sous Vendor/OneSignalXCFramework :
# la résolution distante s'enlise par moments sur les runners GitHub (7 binaryTarget,
# ~117 Mo tirés des releases, que rien ne borne). Seul le produit `OneSignalFramework`
# est lié (ni InAppMessages ni Location).
ONESIGNAL_PKG = uid()
ONESIGNAL_PROD = uid()
ONESIGNAL_BUILD_FILE = uid()


def filetype(name):
    if name.endswith(".swift"):
        return "sourcecode.swift"
    if name.endswith(".xcassets"):
        return "folder.assetcatalog"
    if name.endswith(".plist"):
        return "text.plist.xml"
    return "text"


lines = []
w = lines.append

w("// !$*UTF8*$!")
w("{")
w("\tarchiveVersion = 1;")
w("\tclasses = {")
w("\t};")
w("\tobjectVersion = 56;")
w("\tobjects = {")

w("\n/* Begin PBXBuildFile section */")
for name in swift_files:
    w("\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };"
      % (build[name], name, refs[name], name))
for name in resources:
    w("\t\t%s /* %s in Resources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };"
      % (build[name], name, refs[name], name))
w("\t\t%s /* OneSignalFramework in Frameworks */ = {isa = PBXBuildFile; productRef = %s /* OneSignalFramework */; };"
  % (ONESIGNAL_BUILD_FILE, ONESIGNAL_PROD))
w("/* End PBXBuildFile section */")

w("\n/* Begin PBXFileReference section */")
for name in swift_files + resources + ["Info.plist"]:
    w("\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = %s; path = %s; sourceTree = \"<group>\"; };"
      % (refs[name], name, filetype(name), name))
w("\t\t%s /* %s.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; "
  "path = %s.app; sourceTree = BUILT_PRODUCTS_DIR; };" % (PRODUCT_REF, TARGET, TARGET))
w("/* End PBXFileReference section */")

w("\n/* Begin PBXFrameworksBuildPhase section */")
w("\t\t%s = {" % FRAMEWORKS_PHASE)
w("\t\t\tisa = PBXFrameworksBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
w("\t\t\t\t%s /* OneSignalFramework in Frameworks */," % ONESIGNAL_BUILD_FILE)
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXFrameworksBuildPhase section */")

w("\n/* Begin PBXGroup section */")
w("\t\t%s = {" % MAIN_GROUP)
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
w("\t\t\t\t%s /* %s */," % (SRC_GROUP, TARGET))
w("\t\t\t\t%s /* Products */," % PRODUCTS_GROUP)
w("\t\t\t);")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
w("\t\t%s /* %s */ = {" % (SRC_GROUP, TARGET))
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
for name in swift_files + resources + ["Info.plist"]:
    w("\t\t\t\t%s /* %s */," % (refs[name], name))
w("\t\t\t);")
w("\t\t\tpath = %s;" % TARGET)
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
w("\t\t%s /* Products */ = {" % PRODUCTS_GROUP)
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
w("\t\t\t\t%s /* %s.app */," % (PRODUCT_REF, TARGET))
w("\t\t\t);")
w("\t\t\tname = Products;")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
w("/* End PBXGroup section */")

w("\n/* Begin PBXNativeTarget section */")
w("\t\t%s /* %s */ = {" % (TARGET_ID, TARGET))
w("\t\t\tisa = PBXNativeTarget;")
w("\t\t\tbuildConfigurationList = %s;" % TARGET_CONF_LIST)
w("\t\t\tbuildPhases = (")
w("\t\t\t\t%s," % SOURCES_PHASE)
w("\t\t\t\t%s," % FRAMEWORKS_PHASE)
w("\t\t\t\t%s," % RESOURCES_PHASE)
w("\t\t\t);")
w("\t\t\tbuildRules = (")
w("\t\t\t);")
w("\t\t\tdependencies = (")
w("\t\t\t);")
w("\t\t\tname = %s;" % TARGET)
w("\t\t\tpackageProductDependencies = (")
w("\t\t\t\t%s /* OneSignalFramework */," % ONESIGNAL_PROD)
w("\t\t\t);")
w("\t\t\tproductName = %s;" % TARGET)
w("\t\t\tproductReference = %s;" % PRODUCT_REF)
w("\t\t\tproductType = \"com.apple.product-type.application\";")
w("\t\t};")
w("/* End PBXNativeTarget section */")

w("\n/* Begin PBXProject section */")
w("\t\t%s /* Project object */ = {" % PROJECT_ID)
w("\t\t\tisa = PBXProject;")
w("\t\t\tattributes = {")
w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
w("\t\t\t\tLastSwiftUpdateCheck = 2600;")
w("\t\t\t\tLastUpgradeCheck = 2600;")
w("\t\t\t\tTargetAttributes = {")
w("\t\t\t\t\t%s = {" % TARGET_ID)
w("\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;")
w("\t\t\t\t\t};")
w("\t\t\t\t};")
w("\t\t\t};")
w("\t\t\tbuildConfigurationList = %s;" % PROJ_CONF_LIST)
w("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
w("\t\t\tdevelopmentRegion = en;")
w("\t\t\thasScannedForEncodings = 0;")
w("\t\t\tknownRegions = (")
w("\t\t\t\ten,")
w("\t\t\t\tBase,")
w("\t\t\t);")
w("\t\t\tmainGroup = %s;" % MAIN_GROUP)
w("\t\t\tpackageReferences = (")
w("\t\t\t\t%s /* XCLocalSwiftPackageReference \"Vendor/OneSignalXCFramework\" */," % ONESIGNAL_PKG)
w("\t\t\t);")
w("\t\t\tproductRefGroup = %s /* Products */;" % PRODUCTS_GROUP)
w("\t\t\tprojectDirPath = \"\";")
w("\t\t\tprojectRoot = \"\";")
w("\t\t\ttargets = (")
w("\t\t\t\t%s /* %s */," % (TARGET_ID, TARGET))
w("\t\t\t);")
w("\t\t};")
w("/* End PBXProject section */")

w("\n/* Begin XCLocalSwiftPackageReference section */")
w("\t\t%s /* XCLocalSwiftPackageReference \"Vendor/OneSignalXCFramework\" */ = {" % ONESIGNAL_PKG)
w("\t\t\tisa = XCLocalSwiftPackageReference;")
w("\t\t\trelativePath = \"Vendor/OneSignalXCFramework\";")
w("\t\t};")
w("/* End XCLocalSwiftPackageReference section */")

w("\n/* Begin XCSwiftPackageProductDependency section */")
w("\t\t%s /* OneSignalFramework */ = {" % ONESIGNAL_PROD)
w("\t\t\tisa = XCSwiftPackageProductDependency;")
w("\t\t\tpackage = %s /* XCLocalSwiftPackageReference \"Vendor/OneSignalXCFramework\" */;" % ONESIGNAL_PKG)
w("\t\t\tproductName = OneSignalFramework;")
w("\t\t};")
w("/* End XCSwiftPackageProductDependency section */")

w("\n/* Begin PBXResourcesBuildPhase section */")
w("\t\t%s = {" % RESOURCES_PHASE)
w("\t\t\tisa = PBXResourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for name in resources:
    w("\t\t\t\t%s /* %s in Resources */," % (build[name], name))
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXResourcesBuildPhase section */")

w("\n/* Begin PBXSourcesBuildPhase section */")
w("\t\t%s = {" % SOURCES_PHASE)
w("\t\t\tisa = PBXSourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for name in swift_files:
    w("\t\t\t\t%s /* %s in Sources */," % (build[name], name))
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXSourcesBuildPhase section */")

COMMON = """\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
"""

w("\n/* Begin XCBuildConfiguration section */")
for conf_id, name, extra in [
    (PROJ_DEBUG, "Debug", "\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";\n"
                          "\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;\n"
                          "\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;\n"
                          "\t\t\t\tONLY_ACTIVE_ARCH = YES;\n"
                          "\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;\n"),
    (PROJ_RELEASE, "Release", "\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";\n"
                              "\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;\n"
                              "\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";\n"
                              "\t\t\t\tVALIDATE_PRODUCT = YES;\n"),
]:
    w("\t\t%s /* %s */ = {" % (conf_id, name))
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    lines.append(COMMON + extra.rstrip("\n"))
    w("\t\t\t};")
    w("\t\t\tname = %s;" % name)
    w("\t\t};")

TARGET_COMMON = """\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = SereneDriving/SereneDriving.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tDEVELOPMENT_TEAM = 2E6D4Q69QB;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = "{target}/Info.plist";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {bundle};
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
""".format(target=TARGET, bundle=BUNDLE_ID)

for conf_id, name in [(TARGET_DEBUG, "Debug"), (TARGET_RELEASE, "Release")]:
    w("\t\t%s /* %s */ = {" % (conf_id, name))
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    lines.append(TARGET_COMMON.rstrip("\n"))
    w("\t\t\t};")
    w("\t\t\tname = %s;" % name)
    w("\t\t};")
w("/* End XCBuildConfiguration section */")

w("\n/* Begin XCConfigurationList section */")
for list_id, debug_id, release_id, label in [
    (PROJ_CONF_LIST, PROJ_DEBUG, PROJ_RELEASE, "PBXProject"),
    (TARGET_CONF_LIST, TARGET_DEBUG, TARGET_RELEASE, "PBXNativeTarget"),
]:
    w("\t\t%s /* Build configuration list for %s */ = {" % (list_id, label))
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w("\t\t\t\t%s /* Debug */," % debug_id)
    w("\t\t\t\t%s /* Release */," % release_id)
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")
w("/* End XCConfigurationList section */")

w("\t};")
w("\trootObject = %s /* Project object */;" % PROJECT_ID)
w("}")

os.makedirs(PROJ_DIR, exist_ok=True)
with open(os.path.join(PROJ_DIR, "project.pbxproj"), "w") as f:
    f.write("\n".join(lines) + "\n")

# A shared scheme, so `xcodebuild -scheme SereneDriving` works in CI.
SCHEME_DIR = os.path.join(PROJ_DIR, "xcshareddata", "xcschemes")
os.makedirs(SCHEME_DIR, exist_ok=True)
scheme = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_id}"
               BuildableName = "{target}.app"
               BlueprintName = "{target}"
               ReferencedContainer = "container:{target}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{target}.app"
            BlueprintName = "{target}"
            ReferencedContainer = "container:{target}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{target}.app"
            BlueprintName = "{target}"
            ReferencedContainer = "container:{target}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
""".format(target=TARGET, target_id=TARGET_ID)
with open(os.path.join(SCHEME_DIR, TARGET + ".xcscheme"), "w") as f:
    f.write(scheme)

print("wrote %s (%d swift files) + shared scheme" % (os.path.join(PROJ_DIR, "project.pbxproj"), len(swift_files)))
