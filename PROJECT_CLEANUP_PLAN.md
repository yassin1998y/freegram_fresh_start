# Project Cleanup Plan - Systematic Code Cleanup

## Overview
This document outlines the systematic process for cleaning up the Flutter project, following senior developer best practices.

## Phase 1: Easy Wins (Unused Code & Imports)

### 1.1 Unused Private Methods & Variables
**Status:** ✅ Found 8 unused private methods in `for_you_feed_bloc.dart`

**Issues Found:**
- `_mixFeedItems` (line 347) - Not referenced
- `_getNearbyPosts` (line 552) - Not referenced  
- `_getUserRecentPosts` (line 569) - Not referenced
- `_getAdWithTimeout` (line 601) - Not referenced
- `_getFriendSuggestions` (line 618) - Not referenced
- `_safeGetTrendingPosts` (line 654) - Not referenced
- `_safeGetBoostedPosts` (line 676) - Not referenced
- Unnecessary `!` operator (line 198)

**Action:** Remove unused methods or implement if needed

### 1.2 Unnecessary Casts
**Status:** ✅ Found 3 unnecessary casts in `nearby_feed_bloc.dart`

**Issues Found:**
- Line 122: Unnecessary cast
- Line 123: Unnecessary cast
- Line 124: Unnecessary cast

**Action:** Remove unnecessary casts

### 1.3 Unused Imports
**Status:** 🔄 To be analyzed

**Action:** Run IDE "Optimize Imports" or use `dart fix --apply` for unused imports

## Phase 2: Advanced Analysis

### 2.1 Setup dart_code_metrics
**Status:** ❌ Skipped (Dependency conflict with uuid package)

**Alternative Approach:**
- Use built-in `dart analyze` for basic analysis
- Use IDE "Locate Duplicates" feature (Android Studio/IntelliJ)
- Manual code review for duplication patterns

### 2.2 Find Unused Files
**Method:** Manual review + IDE analysis

**Action:** 
- Review file structure
- Check imports to identify unused files
- Use IDE "Find Usages" to verify files are referenced

### 2.3 Find Code Duplication
**Method:** IDE "Locate Duplicates" + Manual Review

**Action:** 
- Use Android Studio: Right-click `lib/` > Analyze > Locate Duplicates
- Manual review of similar widgets (PostCard, ReelCard, StoryCard headers)
- Extract duplicated code into reusable widgets/functions

## Phase 3: Code Duplication Analysis

### 3.1 Potential Duplication Areas
**Status:** 🔍 Identified

**Areas to Review:**
1. **Card Headers:** PostCard, ReelCard, StoryCard may have similar header patterns
2. **Action Buttons:** Multiple button implementations with similar styling
3. **Progress Indicators:** Upload progress, loading states
4. **Bottom Sheets:** Comments, settings, preview sheets
5. **App Bars:** Similar app bar patterns across screens

**Action:** Use IDE "Locate Duplicates" or manual review

## Phase 4: Refactoring Strategy

### 4.1 Create Reusable Components
**Target Areas:**
- `MediaHeader` widget (extract from PostCard, ReelCard, StoryCard)
- `ActionButton` widget (consolidate button patterns)
- `ProgressIndicator` widget (unify progress displays)
- `BottomSheetBase` widget (common bottom sheet patterns)

### 4.2 Consolidate Services
**Review:**
- Similar service patterns
- Duplicate utility functions
- Common repository methods

## Phase 5: Testing & Validation

### 5.1 After Each Change
- Run `flutter test` to ensure no regressions
- Run `flutter analyze` to check for new issues
- Manual testing of affected features

### 5.2 Final Validation
- Full test suite passes
- No new linter warnings
- App runs without errors
- Code review

## Implementation Order

1. ✅ **Fix Easy Wins** (Unused methods, unnecessary casts)
2. ✅ **Run Auto-Fixes** (903 fixes applied via `dart fix --apply`)
3. ✅ **Advanced Analysis** (Identified duplication patterns)
4. ⏳ **Extract Reusable Components** (See CLEANUP_FINDINGS_AND_RECOMMENDATIONS.md)
5. ⏳ **Final Review** (Test, validate, document)

## Progress Summary

### ✅ Completed
- Removed 8 unused private methods (~200 lines)
- Fixed 3 unnecessary casts
- Removed unused imports
- Applied 903 auto-fixes across 109 files
- **0 linter errors remaining**

### 🔍 Analysis Complete
- Identified 116 progress indicator instances
- Identified 261 button instances
- Identified duplicated header patterns
- Created detailed recommendations document

### ⏳ Next Steps
See `CLEANUP_FINDINGS_AND_RECOMMENDATIONS.md` for detailed extraction plan

## Tools & Commands

### Basic Analysis
```bash
# Run Dart analyzer
dart analyze

# Fix auto-fixable issues
dart fix --apply

# Run tests
flutter test
```

### Advanced Analysis (Using Built-in Tools)
```bash
# Run Dart analyzer (finds unused imports, variables, methods)
dart analyze

# Fix auto-fixable issues
dart fix --apply

# Run tests to ensure no regressions
flutter test

# IDE Tools (Android Studio/IntelliJ):
# 1. Right-click lib/ folder > Analyze > Locate Duplicates
# 2. Code > Optimize Imports (removes unused imports)
# 3. Right-click on file > Find Usages (to check if file is used)
```

## Notes

- Always work in a separate git branch: `refactor/cleanup-YYYY-MM-DD`
- Commit changes incrementally (one category at a time)
- Document why code was removed (if not obvious)
- Keep PR descriptions clear and detailed

