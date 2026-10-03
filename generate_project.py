#!/usr/bin/env python3
"""Generates the AstraAI.xcodeproj/project.pbxproj file with all source files."""

import os
import uuid
import hashlib

def gen_uuid(seed):
    """Generate a deterministic 24-char hex UUID for pbxproj objects."""
    h = hashlib.sha256(seed.encode()).hexdigest()[:24].upper()
    return h

def main():
    project_root = "/home/user/workspace/AstraAI"
    app_dir = os.path.join(project_root, "AstraAI")
    test_dir = os.path.join(project_root, "AstraAITests")
    
    # Collect all Swift files
    swift_files = []
    for root, dirs, files in os.walk(app_dir):
        for f in files:
            if f.endswith('.swift'):
                rel_path = os.path.relpath(os.path.join(root, f), app_dir)
                swift_files.append((f, rel_path))
    
    test_files = []
    for root, dirs, files in os.walk(test_dir):
        for f in files:
            if f.endswith('.swift'):
                rel_path = os.path.relpath(os.path.join(root, f), test_dir)
                test_files.append((f, rel_path))
    
    # Generate UUIDs
    # Project
    proj_uuid = gen_uuid("project")
    main_group_uuid = gen_uuid("main_group")
    app_target_uuid = gen_uuid("app_target")
    test_target_uuid = gen_uuid("test_target")
    
    # Build config lists
    proj_config_list = gen_uuid("proj_config_list")
    app_config_list = gen_uuid("app_config_list")
    test_config_list = gen_uuid("test_config_list")
    
    # Build configs
    proj_debug = gen_uuid("proj_debug")
    proj_release = gen_uuid("proj_release")
    app_debug = gen_uuid("app_debug")
    app_release = gen_uuid("app_release")
    test_debug = gen_uuid("test_debug")
    test_release = gen_uuid("test_release")
    
    # Build phases
    app_sources = gen_uuid("app_sources")
    app_frameworks = gen_uuid("app_frameworks")
    app_resources = gen_uuid("app_resources")
    test_sources = gen_uuid("test_sources")
    test_frameworks = gen_uuid("test_frameworks")
    test_resources = gen_uuid("test_resources")
    
    # Product references
    app_product = gen_uuid("app_product")
    test_product = gen_uuid("test_product")
    app_product_ref = gen_uuid("app_product_ref")
    test_product_ref = gen_uuid("test_product_ref")
    
    # Groups
    app_group = gen_uuid("app_group")
    core_group = gen_uuid("core_group")
    agent_group = gen_uuid("agent_group")
    providers_group = gen_uuid("providers_group")
    skills_core_group = gen_uuid("skills_core_group")
    storage_group = gen_uuid("storage_group")
    networking_group = gen_uuid("networking_group")
    skills_group = gen_uuid("skills_group")
    ui_group = gen_uuid("ui_group")
    chat_group = gen_uuid("chat_group")
    voice_group = gen_uuid("voice_group")
    skills_ui_group = gen_uuid("skills_ui_group")
    memory_group = gen_uuid("memory_group")
    history_group = gen_uuid("history_group")
    settings_group = gen_uuid("settings_group")
    resources_group = gen_uuid("resources_group")
    test_group = gen_uuid("test_group")
    products_group = gen_uuid("products_group")
    
    # File references and build files
    file_refs = {}  # filename -> uuid
    build_files = {}  # filename -> uuid
    
    all_files = [(f, p, "app") for f, p in swift_files] + [(f, p, "test") for f, p in test_files]
    
    for filename, rel_path, target in all_files:
        file_refs[filename] = gen_uuid(f"fileref_{filename}")
        build_files[filename] = gen_uuid(f"buildfile_{filename}")
    
    # Info.plist reference
    infoplist_ref = gen_uuid("infoplist_ref")
    
    # Build the pbxproj
    lines = []
    lines.append("// !$*UTF8*$!")
    lines.append("{")
    lines.append("\tarchiveVersion = 1;")
    lines.append("\tclasses = {")
    lines.append("\t};")
    lines.append("\tobjectVersion = 56;")
    lines.append("\tobjects = {")
    lines.append("")
    
    # PBXBuildFile section
    lines.append("/* Begin PBXBuildFile section */")
    for filename, rel_path, target in all_files:
        build_id = build_files[filename]
        ref_id = file_refs[filename]
        lines.append(f"\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_id} /* {filename} */; }};")
    lines.append("/* End PBXBuildFile section */")
    lines.append("")
    
    # PBXFileReference section
    lines.append("/* Begin PBXFileReference section */")
    for filename, rel_path, target in all_files:
        ref_id = file_refs[filename]
        if target == "app":
            path = f"AstraAI/{rel_path}"
        else:
            path = f"AstraAITests/{rel_path}"
        lines.append(f"\t\t{ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{path}\"; sourceTree = \"<group>\"; }};")
    
    # Product references
    lines.append(f"\t\t{app_product_ref} /* AstraAI.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AstraAI.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    lines.append(f"\t\t{test_product_ref} /* AstraAITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = AstraAITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    
    # Info.plist
    lines.append(f"\t\t{infoplist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = \"AstraAI/Resources/Info.plist\"; sourceTree = \"<group>\"; }};")
    
    lines.append("/* End PBXFileReference section */")
    lines.append("")
    
    # PBXFrameworksBuildPhase section
    lines.append("/* Begin PBXFrameworksBuildPhase section */")
    lines.append(f"\t\t{app_frameworks} /* Frameworks */ = {{")
    lines.append(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append(f"\t\t\tbuildActionMask = 2147483647;")
    lines.append(f"\t\t\tfiles = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t}};")
    lines.append(f"\t\t{test_frameworks} /* Frameworks */ = {{")
    lines.append(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append(f"\t\t\tbuildActionMask = 2147483647;")
    lines.append(f"\t\t\tfiles = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t}};")
    lines.append("/* End PBXFrameworksBuildPhase section */")
    lines.append("")
    
    # PBXGroup section
    lines.append("/* Begin PBXGroup section */")
    
    def make_group(gid, name, children, path=None):
        result = []
        result.append(f"\t\t{gid} /* {name} */ = {{")
        result.append(f"\t\t\tisa = PBXGroup;")
        result.append(f"\t\t\tchildren = (")
        for child_id, child_comment in children:
            result.append(f"\t\t\t\t{child_id} /* {child_comment} */,")
        result.append(f"\t\t\t);")
        if path:
            result.append(f"\t\t\tpath = \"{path}\";")
        result.append(f"\t\t\tsourceTree = \"<group>\";")
        result.append(f"\t\t}};")
        return "\n".join(result)
    
    # Organize files by directory
    def files_in_dir(dir_name, target="app"):
        source = swift_files if target == "app" else test_files
        return [(file_refs[f], f) for f, p in source if os.path.dirname(p) == dir_name]
    
    # Core sub-groups
    agent_files = files_in_dir("Core/Agent")
    providers_files = files_in_dir("Core/Providers")
    skills_core_files = files_in_dir("Core/Skills")
    storage_files = files_in_dir("Core/Storage")
    networking_files = files_in_dir("Core/Networking")
    
    lines.append(make_group(agent_group, "Agent", agent_files, "Core/Agent"))
    lines.append(make_group(providers_group, "Providers", providers_files, "Core/Providers"))
    lines.append(make_group(skills_core_group, "Skills", skills_core_files, "Core/Skills"))
    lines.append(make_group(storage_group, "Storage", storage_files, "Core/Storage"))
    lines.append(make_group(networking_group, "Networking", networking_files, "Core/Networking"))
    
    core_children = [
        (agent_group, "Agent"),
        (providers_group, "Providers"),
        (skills_core_group, "Skills"),
        (storage_group, "Storage"),
        (networking_group, "Networking"),
    ]
    lines.append(make_group(core_group, "Core", core_children, "Core"))
    
    # Skills sub-groups
    skill_dirs = ["WebSearch", "News", "WebBrowser", "Voice", "Vision", "Files", "Memory", "Calendar", "Reminders", "Weather", "API", "Code"]
    skill_group_uuids = {}
    for sd in skill_dirs:
        gid = gen_uuid(f"skill_dir_{sd}")
        skill_group_uuids[sd] = gid
        sfiles = files_in_dir(f"Skills/{sd}")
        lines.append(make_group(gid, sd, sfiles, f"Skills/{sd}"))
    
    skill_children = [(skill_group_uuids[sd], sd) for sd in skill_dirs]
    lines.append(make_group(skills_group, "Skills", skill_children, "Skills"))
    
    # UI sub-groups
    chat_files = files_in_dir("UI/Chat")
    voice_files = files_in_dir("UI/Voice")
    skills_ui_files = files_in_dir("UI/Skills")
    memory_files = files_in_dir("UI/Memory")
    history_files = files_in_dir("UI/History")
    settings_files = files_in_dir("UI/Settings")
    
    lines.append(make_group(chat_group, "Chat", chat_files, "UI/Chat"))
    lines.append(make_group(voice_group, "Voice", voice_files, "UI/Voice"))
    lines.append(make_group(skills_ui_group, "Skills", skills_ui_files, "UI/Skills"))
    lines.append(make_group(memory_group, "Memory", memory_files, "UI/Memory"))
    lines.append(make_group(history_group, "History", history_files, "UI/History"))
    lines.append(make_group(settings_group, "Settings", settings_files, "UI/Settings"))
    
    ui_children = [
        (chat_group, "Chat"),
        (voice_group, "Voice"),
        (skills_ui_group, "Skills"),
        (memory_group, "Memory"),
        (history_group, "History"),
        (settings_group, "Settings"),
    ]
    
    # RootView is in UI/ directly
    rootview_files = files_in_dir("UI")
    ui_children_with_files = rootview_files + ui_children
    lines.append(make_group(ui_group, "UI", ui_children_with_files, "UI"))
    
    # App group (files in App/ directory)
    app_files = files_in_dir("App")
    app_group_children = app_files + [
        (core_group, "Core"),
        (skills_group, "Skills"),
        (ui_group, "UI"),
        (resources_group, "Resources"),
    ]
    lines.append(make_group(app_group, "AstraAI", app_group_children, "AstraAI"))
    
    # Resources group
    lines.append(make_group(resources_group, "Resources", [(infoplist_ref, "Info.plist")], "AstraAI/Resources"))
    
    # Products group
    lines.append(make_group(products_group, "Products", [
        (app_product_ref, "AstraAI.app"),
        (test_product_ref, "AstraAITests.xctest"),
    ]))
    
    # Test group
    test_children = [(file_refs[f], f) for f, p in test_files]
    lines.append(make_group(test_group, "AstraAITests", test_children, "AstraAITests"))
    
    # Main group
    main_children = [
        (app_group, "AstraAI"),
        (test_group, "AstraAITests"),
        (products_group, "Products"),
    ]
    lines.append(make_group(main_group_uuid, "", main_children))
    
    lines.append("/* End PBXGroup section */")
    lines.append("")
    
    # PBXNativeTarget section
    lines.append("/* Begin PBXNativeTarget section */")
    
    # App source files
    app_source_files = [(build_files[f], f) for f, p in swift_files]
    
    lines.append(f"\t\t{app_target_uuid} /* AstraAI */ = {{")
    lines.append(f"\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {app_config_list} /* Build configuration list for PBXNativeTarget \"AstraAI\" */;")
    lines.append(f"\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{app_sources} /* Sources */,")
    lines.append(f"\t\t\t\t{app_frameworks} /* Frameworks */,")
    lines.append(f"\t\t\t\t{app_resources} /* Resources */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tbuildRules = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tdependencies = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tname = AstraAI;")
    lines.append(f"\t\t\tpackageProductDependencies = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tproductName = AstraAI;")
    lines.append(f"\t\t\tproductReference = {app_product_ref} /* AstraAI.app */;")
    lines.append(f"\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append(f"\t\t}};")
    
    # Test target
    test_source_files = [(build_files[f], f) for f, p in test_files]
    
    lines.append(f"\t\t{test_target_uuid} /* AstraAITests */ = {{")
    lines.append(f"\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {test_config_list} /* Build configuration list for PBXNativeTarget \"AstraAITests\" */;")
    lines.append(f"\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{test_sources} /* Sources */,")
    lines.append(f"\t\t\t\t{test_frameworks} /* Frameworks */,")
    lines.append(f"\t\t\t\t{test_resources} /* Resources */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tbuildRules = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tdependencies = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tname = AstraAITests;")
    lines.append(f"\t\t\tpackageProductDependencies = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tproductName = AstraAITests;")
    lines.append(f"\t\t\tproductReference = {test_product_ref} /* AstraAITests.xctest */;")
    lines.append(f"\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    lines.append(f"\t\t}};")
    
    lines.append("/* End PBXNativeTarget section */")
    lines.append("")
    
    # PBXProject section
    lines.append("/* Begin PBXProject section */")
    lines.append(f"\t\t{proj_uuid} /* Project object */ = {{")
    lines.append(f"\t\t\tisa = PBXProject;")
    lines.append(f"\t\t\tattributes = {{")
    lines.append(f"\t\t\t\tLastSwiftUpdateCheck = 1600;")
    lines.append(f"\t\t\t\tLastUpgradeCheck = 1600;")
    lines.append(f"\t\t\t\tTargetAttributes = {{")
    lines.append(f"\t\t\t\t\t{app_target_uuid} = {{")
    lines.append(f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    lines.append(f"\t\t\t\t\t}};")
    lines.append(f"\t\t\t\t\t{test_target_uuid} = {{")
    lines.append(f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    lines.append(f"\t\t\t\t\t\tTestTargetID = {app_target_uuid};")
    lines.append(f"\t\t\t\t\t}};")
    lines.append(f"\t\t\t\t}};")
    lines.append(f"\t\t\t}};")
    lines.append(f"\t\t\tbuildConfigurationList = {proj_config_list} /* Build configuration list for PBXProject \"AstraAI\" */;")
    lines.append(f"\t\t\tcompatibilityVersion = \"Xcode 15.0\";")
    lines.append(f"\t\t\tdevelopmentRegion = \"fr\";")
    lines.append(f"\t\t\thasScannedForEncodings = 0;")
    lines.append(f"\t\t\tknownRegions = (")
    lines.append(f"\t\t\t\t\"en\",")
    lines.append(f"\t\t\t\t\"fr\",")
    lines.append(f"\t\t\t\tBase,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tmainGroup = {main_group_uuid};")
    lines.append(f"\t\t\tpackageReferences = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
    lines.append(f"\t\t\tprojectDirPath = \"\";")
    lines.append(f"\t\t\tprojectRoot = \"\";")
    lines.append(f"\t\t\ttargets = (")
    lines.append(f"\t\t\t\t{app_target_uuid} /* AstraAI */,")
    lines.append(f"\t\t\t\t{test_target_uuid} /* AstraAITests */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t}};")
    lines.append("/* End PBXProject section */")
    lines.append("")
    
    # PBXResourcesBuildPhase
    lines.append("/* Begin PBXResourcesBuildPhase section */")
    lines.append(f"\t\t{app_resources} /* Resources */ = {{")
    lines.append(f"\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append(f"\t\t\tbuildActionMask = 2147483647;")
    lines.append(f"\t\t\tfiles = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t}};")
    lines.append(f"\t\t{test_resources} /* Resources */ = {{")
    lines.append(f"\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append(f"\t\t\tbuildActionMask = 2147483647;")
    lines.append(f"\t\t\tfiles = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t}};")
    lines.append("/* End PBXResourcesBuildPhase section */")
    lines.append("")
    
    # PBXSourcesBuildPhase
    lines.append("/* Begin PBXSourcesBuildPhase section */")
    lines.append(f"\t\t{app_sources} /* Sources */ = {{")
    lines.append(f"\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append(f"\t\t\tbuildActionMask = 2147483647;")
    lines.append(f"\t\t\tfiles = (")
    for build_id, filename in app_source_files:
        lines.append(f"\t\t\t\t{build_id} /* {filename} in Sources */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t}};")
    lines.append(f"\t\t{test_sources} /* Sources */ = {{")
    lines.append(f"\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append(f"\t\t\tbuildActionMask = 2147483647;")
    lines.append(f"\t\t\tfiles = (")
    for build_id, filename in test_source_files:
        lines.append(f"\t\t\t\t{build_id} /* {filename} in Sources */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t}};")
    lines.append("/* End PBXSourcesBuildPhase section */")
    lines.append("")
    
    # XCBuildConfiguration
    lines.append("/* Begin XCBuildConfiguration section */")
    
    def build_config(cid, name, target_type="project", is_test=False):
        result = []
        result.append(f"\t\t{cid} /* {name} */ = {{")
        result.append(f"\t\t\tisa = XCBuildConfiguration;")
        if target_type == "project":
            result.append(f"\t\t\tbuildSettings = {{")
            result.append(f"\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
            result.append(f"\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;")
            result.append(f"\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
            result.append(f"\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;")
            result.append(f"\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
            result.append(f"\t\t\t\tCLANG_ENABLE_MODULES = YES;")
            result.append(f"\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
            result.append(f"\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_COMMA = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;")
            result.append(f"\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;")
            result.append(f"\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;")
            result.append(f"\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;")
            result.append(f"\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;")
            result.append(f"\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;")
            result.append(f"\t\t\t\tCOPY_PHASE_STRIP = NO;")
            result.append(f"\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
            result.append(f"\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
            result.append(f"\t\t\t\tENABLE_TESTABILITY = YES;")
            result.append(f"\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;")
            result.append(f"\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
            result.append(f"\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
            result.append(f"\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
            result.append(f"\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
            result.append(f"\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (")
            result.append(f"\t\t\t\t\t\"DEBUG=1\",")
            result.append(f"\t\t\t\t\t\"$(inherited)\",")
            result.append(f"\t\t\t\t);")
            result.append(f"\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;")
            result.append(f"\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;")
            result.append(f"\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;")
            result.append(f"\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;")
            result.append(f"\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;")
            result.append(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
            result.append(f"\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;")
            result.append(f"\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
            result.append(f"\t\t\t\tMTL_FAST_MATH = YES;")
            result.append(f"\t\t\t\tONLY_ACTIVE_ARCH = YES;")
            result.append(f"\t\t\t\tSDKROOT = iphoneos;")
            result.append(f"\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"$(inherited) DEBUG\";")
            result.append(f"\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
            result.append(f"\t\t\t}};")
            result.append(f"\t\t\tname = {name};")
        elif target_type == "app":
            result.append(f"\t\t\tbuildSettings = {{")
            result.append(f"\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
            result.append(f"\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
            result.append(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
            result.append(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
            result.append(f"\t\t\t\tDEVELOPMENT_TEAM = \"\";")
            result.append(f"\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
            result.append(f"\t\t\t\tINFOPLIST_FILE = AstraAI/Resources/Info.plist;")
            result.append(f"\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"Astra AI\";")
            result.append(f"\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;")
            result.append(f"\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;")
            result.append(f"\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = \"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\";")
            result.append(f"\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = \"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\";")
            result.append(f"\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
            result.append(f"\t\t\t\t\t\"$(inherited)\",")
            result.append(f"\t\t\t\t\t\"@executable_path/Frameworks\",")
            result.append(f"\t\t\t\t);")
            result.append(f"\t\t\t\tMARKETING_VERSION = 1.0;")
            result.append(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.astraai.app;")
            result.append(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
            result.append(f"\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
            result.append(f"\t\t\t\tSWIFT_VERSION = 5.0;")
            result.append(f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
            result.append(f"\t\t\t}};")
            result.append(f"\t\t\tname = {name};")
        elif target_type == "test":
            result.append(f"\t\t\tbuildSettings = {{")
            result.append(f"\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";")
            result.append(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
            result.append(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
            result.append(f"\t\t\t\tDEVELOPMENT_TEAM = \"\";")
            result.append(f"\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
            result.append(f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
            result.append(f"\t\t\t\tMARKETING_VERSION = 1.0;")
            result.append(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.astraai.app.tests;")
            result.append(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
            result.append(f"\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;")
            result.append(f"\t\t\t\tSWIFT_VERSION = 5.0;")
            result.append(f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
            result.append(f"\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/AstraAI.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/AstraAI\";")
            result.append(f"\t\t\t}};")
            result.append(f"\t\t\tname = {name};")
        result.append(f"\t\t}};")
        return "\n".join(result)
    
    lines.append(build_config(proj_debug, "Debug", "project"))
    lines.append(build_config(proj_release, "Release", "project"))
    lines.append(build_config(app_debug, "Debug", "app"))
    lines.append(build_config(app_release, "Release", "app"))
    lines.append(build_config(test_debug, "Debug", "test"))
    lines.append(build_config(test_release, "Release", "test"))
    
    lines.append("/* End XCBuildConfiguration section */")
    lines.append("")
    
    # XCConfigurationList
    lines.append("/* Begin XCConfigurationList section */")
    
    lines.append(f"\t\t{proj_config_list} /* Build configuration list for PBXProject \"AstraAI\" */ = {{")
    lines.append(f"\t\t\tisa = XCConfigurationList;")
    lines.append(f"\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{proj_debug} /* Debug */,")
    lines.append(f"\t\t\t\t{proj_release} /* Release */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append(f"\t\t\tdefaultConfigurationName = Release;")
    lines.append(f"\t\t}};")
    
    lines.append(f"\t\t{app_config_list} /* Build configuration list for PBXNativeTarget \"AstraAI\" */ = {{")
    lines.append(f"\t\t\tisa = XCConfigurationList;")
    lines.append(f"\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{app_debug} /* Debug */,")
    lines.append(f"\t\t\t\t{app_release} /* Release */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append(f"\t\t\tdefaultConfigurationName = Release;")
    lines.append(f"\t\t}};")
    
    lines.append(f"\t\t{test_config_list} /* Build configuration list for PBXNativeTarget \"AstraAITests\" */ = {{")
    lines.append(f"\t\t\tisa = XCConfigurationList;")
    lines.append(f"\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{test_debug} /* Debug */,")
    lines.append(f"\t\t\t\t{test_release} /* Release */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append(f"\t\t\tdefaultConfigurationName = Release;")
    lines.append(f"\t\t}};")
    
    lines.append("/* End XCConfigurationList section */")
    lines.append("\t};")
    lines.append("\trootObject = %s /* Project object */;" % proj_uuid)
    lines.append("}")
    
    # Write the file
    output_dir = os.path.join(project_root, "AstraAI.xcodeproj")
    os.makedirs(output_dir, exist_ok=True)
    output_file = os.path.join(output_dir, "project.pbxproj")
    
    with open(output_file, 'w') as f:
        f.write("\n".join(lines))
    
    print(f"Generated {output_file}")
    print(f"App source files: {len(swift_files)}")
    print(f"Test source files: {len(test_files)}")

if __name__ == "__main__":
    main()
