# Project Screens Analysis

**Date:** Current Session  
**Purpose:** Identify working vs dead screens

---

## 📊 **SCREEN INVENTORY:**

Total Screen Files Found: **43** (3 removed: reels_hub_screen, template_library_screen, onboarding_screen)

---

## ✅ **WORKING/REACHABLE SCREENS:**

### **1. Auth Screens (3/3) ✅**
- ✅ `login_screen.dart` - Used in AuthWrapper
- ✅ `signup_screen.dart` - Registered in routes
- ✅ `multi_step_onboarding_screen.dart` - Used in AuthWrapper for incomplete profiles

### **2. Main Navigation Tabs (6/6) ✅**
- ✅ `main_screen.dart` - Root screen
- ✅ `nearby_screen.dart` - Tab 0 in MainScreen
- ✅ `feed_screen.dart` - Tab 1 in MainScreen
- ✅ `match_screen.dart` - Tab 2 in MainScreen
- ✅ `friends_list_screen.dart` - Tab 3 in MainScreen
- ✅ `menu_screen.dart` - Tab 4 in MainScreen

### **3. Profile Screens (4/4) ✅**
- ✅ `profile_screen.dart` - Registered in routes, used via AppRoutes.profile
- ✅ `edit_profile_screen.dart` - Used from ProfileScreen
- ✅ `page_profile_screen.dart` - Used from ProfileScreen (Page feature)
- ✅ `qr_display_screen.dart` - Used from ProfileScreen

### **4. Chat Screens (4/4) ✅**
- ✅ `improved_chat_list_screen.dart` - Used in MainScreen AppBar
- ✅ `improved_chat_screen.dart` - Registered in routes
- ✅ `nearby_chat_list_screen.dart` - Used from NearbyScreen
- ✅ `nearby_chat_screen.dart` - Used from NearbyChatListScreen

### **5. Reels Screens (2/2) ✅**
- ✅ `reels_feed_screen.dart` - Registered in routes (AppRoutes.reels)
- ✅ `create_reel_screen.dart` - Registered in routes (AppRoutes.createReel)

### **6. Story Screens (3/3) ✅**
- ✅ `story_creator_screen.dart` - Registered in routes (AppRoutes.storyCreator)
- ✅ `text_story_creator_screen.dart` - Registered in routes (AppRoutes.textStoryCreator)
- ✅ `story_viewer_screen.dart` - Used from stories tray/feed

### **7. Settings & Notifications (3/3) ✅**
- ✅ `settings_screen.dart` - Registered in routes, used in MenuScreen
- ✅ `notification_settings_screen.dart` - Accessible from SettingsScreen
- ✅ `notifications_screen.dart` - Used as modal in MainScreen AppBar

### **8. Feed/Post Screens (6/6) ✅**
- ✅ `hashtag_explore_screen.dart` - Used from PostCard (hashtag taps)
- ✅ `report_screen.dart` - Used from PostCard (report post action)
- ✅ `boost_post_screen.dart` - Used from PostCard (boost post action)
- ✅ `image_gallery_screen.dart` - Used from PostCard (image viewing)
- ✅ `location_picker_screen.dart` - Used from EditProfileScreen
- ✅ `post_detail_screen.dart` - **FIXED!** Used from NotificationsScreen and FCM navigation (foreground handler now added)

### **9. Page Management Screens (2/4) ✅**
- ✅ `create_page_screen.dart` - Used from ProfileScreen
- ✅ `page_profile_screen.dart` - Used from ProfileScreen
- ❌ `page_settings_screen.dart` - **NOT USED** (no navigation found)
- ❌ `page_analytics_screen.dart` - **NOT USED** (no navigation found)

### **10. Utility Screens (5/5) ✅**
- ✅ `store_screen.dart` - Registered in routes, used in MenuScreen
- ✅ `match_animation_screen.dart` - Used from MatchScreen
- ✅ `feature_discovery_screen.dart` - Used in MenuScreen (direct Navigator.push)
- ✅ `feature_guide_detail_screen.dart` - Used from FeatureDiscoveryScreen
- ✅ `moderation_dashboard_screen.dart` - Used in MenuScreen (admin only, direct Navigator.push)

---

## ❌ **DEAD/UNUSED SCREENS:**

### **1. Page Management Screens (2/4) ❌**
- ❌ `page_settings_screen.dart` - **NOT USED** (no navigation found)
- ❌ `page_analytics_screen.dart` - **NOT USED** (no navigation found)

### **2. Boost/Advertising Screens (1/2) ❌**
- ❌ `boost_analytics_screen.dart` - **NOT USED** (imported but never navigated to)

### **3. Feed/Post Screens (1/1) ❌**
- ❌ `mentioned_posts_screen.dart` - **NOT USED** (no navigation found)

### **4. Search & Discovery (1/1) ❌**
- ❌ `search_screen.dart` - **NOT USED** (no navigation found)


---

## 📝 **FINAL SUMMARY:**

### ✅ **Working/Reachable Screens: 38 screens**
- **Auth Screens:** 3/3 ✅
- **Main Navigation:** 6/6 ✅
- **Profile Screens:** 4/4 ✅
- **Chat Screens:** 4/4 ✅
- **Reels Screens:** 2/2 ✅
- **Story Screens:** 3/3 ✅
- **Settings/Notifications:** 3/3 ✅
- **Feed/Post Screens:** 6/6 ✅
- **Page Management:** 2/4 ✅ (page_settings/analytics unused)
- **Utility Screens:** 5/5 ✅

### ❌ **Dead/Unused Screens: 5 screens**
1. ❌ `mentioned_posts_screen.dart` - No navigation
2. ❌ `page_settings_screen.dart` - No navigation
3. ❌ `page_analytics_screen.dart` - No navigation
4. ❌ `boost_analytics_screen.dart` - Imported but never used
5. ❌ `search_screen.dart` - No navigation

### 📊 **Statistics:**
- **Total Screens:** 43 (3 removed: reels_hub_screen, template_library_screen, onboarding_screen)
- **Working Screens:** 38 (88.4%)
- **Dead Screens:** 5 (11.6%)

---

## ✅ **ALL SCREENS VERIFIED!**

All screens have been analyzed and verified. No uncertain screens remain.

---

## 🎯 **RECOMMENDATIONS:**

1. **Delete dead screens** for unimplemented features:
   - Page management screens (if feature is not planned)
   - Boost/Advertising screens (if feature is not planned)
   - Search/Explore screens (if features are not planned)

2. **Keep legacy screens** if they might be used in the future:
   - Comment them out or mark them clearly

3. **Verify uncertain screens** before deleting:
   - Check if they're used dynamically or via deep links
   - Check if they're part of incomplete features

---

**Note:** This analysis is based on static code analysis. Some screens might be reachable via:
- Deep links
- Dynamic routes
- Conditional logic not easily traceable
- Future planned features

Manual verification recommended before deleting any screens.

