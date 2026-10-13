#!/usr/bin/env python3
"""Generate the small, dependency-free Xcode project; run after adding app Swift files."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent
objects = {}
def oid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name, body): objects[oid(name)] = body; return oid(name)
files = sorted((root / 'Shelf').glob('*.swift'))
refs=[]; builds=[]
for f in files:
    ref=add(str(f.name), '{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "%s"; sourceTree = "<group>";}' % f.name)
    refs.append(ref)
    builds.append(add('build'+f.name, '{isa = PBXBuildFile; fileRef = %s;}'%ref))
def array(values): return '(' + ','.join(values) + ',)'
product=add('product','{isa = PBXFileReference; explicitFileType = wrapper.application; path = Shelf.app; sourceTree = BUILT_PRODUCTS_DIR;}')
appGroup=add('appGroup','{isa = PBXGroup; path = Shelf; sourceTree = "<group>"; children = %s;}'%array(refs))
products=add('products','{isa = PBXGroup; name = Products; sourceTree = "<group>"; children = (%s,);}'%product)
main=add('main','{isa = PBXGroup; sourceTree = "<group>"; children = (%s,%s,);}'%(appGroup,products))
package=add('package','{isa = XCLocalSwiftPackageReference; relativePath = Packages/ShelfCore;}')
packageProduct=add('packageProduct','{isa = XCSwiftPackageProductDependency; package = %s; productName = ShelfCore;}'%package)
packageBuild=add('packageBuild','{isa = PBXBuildFile; productRef = %s;}'%packageProduct)
sources=add('sources','{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = %s; runOnlyForDeploymentPostprocessing = 0;}'%array(builds))
frameworks=add('frameworks','{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (%s,); runOnlyForDeploymentPostprocessing = 0;}'%packageBuild)
resources=add('resources','{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;}')
projectConfigs=[]; targetConfigs=[]
for config in ['Debug','Release']:
    settings='CLANG_ENABLE_MODULES = YES; SDKROOT = appletvos; TVOS_DEPLOYMENT_TARGET = 18.0; SWIFT_VERSION = 6.0;'
    settings+= ' SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; ENABLE_TESTABILITY = YES;' if config=='Debug' else ' SWIFT_COMPILATION_MODE = wholemodule; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
    projectConfigs.append(add('project'+config,'{isa = XCBuildConfiguration; name = %s; buildSettings = {%s};}'%(config,settings)))
    targetSettings='''CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = ALZ45VUZFN; PRODUCT_BUNDLE_IDENTIFIER = com.dreaife.shelf; PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 3; SUPPORTED_PLATFORMS = "appletvos appletvsimulator"; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_CFBundleDisplayName = Shelf; INFOPLIST_KEY_UILaunchScreen_Generation = YES; MARKETING_VERSION = 1.0; CURRENT_PROJECT_VERSION = 1; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"; SWIFT_EMIT_LOC_STRINGS = YES;'''
    targetConfigs.append(add('target'+config,'{isa = XCBuildConfiguration; name = %s; buildSettings = {%s};}'%(config,targetSettings)))
pc=add('projectConfigList','{isa = XCConfigurationList; buildConfigurations = %s; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}'%array(projectConfigs))
tc=add('targetConfigList','{isa = XCConfigurationList; buildConfigurations = %s; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}'%array(targetConfigs))
target=add('target','{isa = PBXNativeTarget; buildConfigurationList = %s; buildPhases = (%s,%s,%s,); buildRules = (); dependencies = (); name = Shelf; packageProductDependencies = (%s,); productName = Shelf; productReference = %s; productType = "com.apple.product-type.application";}'%(tc,sources,frameworks,resources,packageProduct,product))
project=add('project','{isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700; TargetAttributes = {%s = {CreatedOnToolsVersion = 27.0; ProvisioningStyle = Automatic;};};}; buildConfigurationList = %s; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = %s; packageReferences = (%s,); productRefGroup = %s; projectDirPath = ""; projectRoot = ""; targets = (%s,);}'%(target,pc,main,package,products,target))
p=root/'Shelf.xcodeproj';p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = '+v+';' for k,v in objects.items())+'\n}; rootObject = '+project+';\n}\n')
s=p/'xcshareddata/xcschemes';s.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Shelf.app" BlueprintName="Shelf" ReferencedContainer="container:Shelf.xcodeproj"/>'
(s/'Shelf.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"/>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
