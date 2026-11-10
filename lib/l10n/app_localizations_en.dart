// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get addFolder => 'Add Directory';

  @override
  String get openInNewTab => 'Open in New Tab';

  @override
  String get addToFavorites => 'Add to Favourites';

  @override
  String get removeFromFavorites => 'Remove from Favourites';

  @override
  String get favorites => 'Favourites';

  @override
  String get noFavoritesYet => 'No favourites yet';

  @override
  String fileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '$count file',
    );
    return '$_temp0';
  }

  @override
  String get noShelvesYet => 'No bookshelves added yet';

  @override
  String get addingShelf => 'Adding a bookshelf…';

  @override
  String get topPageTitle => 'Top';

  @override
  String get newTab => 'New Tab';

  @override
  String get information => 'Information';

  @override
  String get appTagline => 'Just you and a book';

  @override
  String versionInfo(String version) {
    return 'Version $version';
  }

  @override
  String get licensesSection => 'Open Source Licences';

  @override
  String get licensesButton => 'View Licences';

  @override
  String get shortcutsSection => 'Keyboard Shortcuts';

  @override
  String get shortcutCategoryNavigation => 'Navigation';

  @override
  String get shortcutCategoryTabs => 'Tabs';

  @override
  String get shortcutCategoryScreenFile => 'Screen & Files';

  @override
  String get shortcutCategoryViewer => 'In the Viewer';

  @override
  String get shortcutAltArrow => 'Go back / forward in history';

  @override
  String get shortcutEsc => 'Close the viewer and return to the directory';

  @override
  String get shortcutCtrlTab => 'Switch to the tab on the right / below';

  @override
  String get shortcutCtrlShiftTab => 'Switch to the tab on the left / above';

  @override
  String get shortcutCtrlT => 'Open a new bookshelf tab';

  @override
  String get shortcutCtrlW => 'Close the current tab';

  @override
  String get shortcutMiddleClick =>
      'Close a tab / open a book or directory in a new tab';

  @override
  String get shortcutCtrlI => 'Open settings';

  @override
  String get shortcutCtrlF => 'Focus the sidebar search box';

  @override
  String get shortcutCtrlB => 'Open favourites';

  @override
  String get shortcutF1 => 'Open information';

  @override
  String get shortcutCtrlA => 'Select all directories / files in view';

  @override
  String get shortcutCtrlClick =>
      'Add or remove an individual item from the selection';

  @override
  String get shortcutShiftClick =>
      'Range-select (selects everything from the last click to this one)';

  @override
  String get shortcutF5 => 'Rescan directories and refresh the book list';

  @override
  String get shortcutArrowLeftRight => 'Previous / next page';

  @override
  String get shortcutCtrlArrowLeftRight => 'Go to the first / last page';

  @override
  String get shortcutArrowUpDown =>
      'Open the previous / next book in the same directory';

  @override
  String get shortcutSpace => 'Show or hide the menu bar';

  @override
  String get shortcutT => 'Open the table of contents (books that have one)';

  @override
  String get shortcutP => 'Start / stop auto page turn';

  @override
  String get sidebarSearchHint => 'Search';

  @override
  String get noSearchResults => 'No matching books or directories found';

  @override
  String get deleteFolderTitle => 'Delete Directory';

  @override
  String get deleteFolderConfirm => 'Delete all books in this directory?';

  @override
  String get deleteFailed => 'Failed to delete the file';

  @override
  String get excludeShelf => 'Exclude';

  @override
  String get excludeShelfTitle => 'Exclude Bookshelf';

  @override
  String excludeShelfConfirm(String name) {
    return 'Exclude \"$name\" from dolce?\nThe actual files will not be deleted. To load it again, start over by adding the bookshelf.';
  }

  @override
  String get jumpToFirstPage => 'Go to First Page';

  @override
  String get jumpToLastPage => 'Go to Last Page';

  @override
  String get nextBook => 'Next Book';

  @override
  String get previousBook => 'Previous Book';

  @override
  String get autoPageSecondsUnit => 's';

  @override
  String get autoPageTooltip => 'Auto page turn';

  @override
  String get tableOfContents => 'Table of contents';

  @override
  String get accentColorSection => 'Accent colour';

  @override
  String get accentColorCode => 'Colour code';

  @override
  String get accentColorFormatError => 'Enter a colour in #RRGGBB format';

  @override
  String get accentColorAddPreset => 'Add to presets';

  @override
  String get accentColorAddedBanner => 'Added to presets';

  @override
  String get accentColorCopiedBanner => 'Copied';

  @override
  String get accentPresetDeleteMessage => 'Delete this colour?';

  @override
  String get accentPresetDeleteConfirm => 'Delete';

  @override
  String get accentTextColorSection => 'Text colour on accent';

  @override
  String get accentTextAuto => 'Auto (black / white to suit the accent)';

  @override
  String get accentTextBlack => 'Black';

  @override
  String get accentTextWhite => 'White';

  @override
  String get autoPageStart => 'Start auto page turn';

  @override
  String get autoPageStop => 'Stop auto page turn';

  @override
  String autoPageSecondsItem(int seconds) {
    return 'Every $seconds s';
  }

  @override
  String get orientationPortrait => 'Portrait';

  @override
  String get orientationLandscapeLeft => 'Rotate Left 90°';

  @override
  String get orientationLandscapeRight => 'Rotate Right 90°';

  @override
  String get orientationPortraitDown => '180°';

  @override
  String get refresh => 'Refresh';

  @override
  String get navBack => 'Back';

  @override
  String get navForward => 'Forward';

  @override
  String get navSearch => 'Search';

  @override
  String get navAddTab => 'Add Tab';

  @override
  String get navTabList => 'Tab List';

  @override
  String get navMore => 'More';

  @override
  String get pageDirectionSection => 'Page Direction';

  @override
  String get pageDirectionLeftTitle => 'Next Page on the Left';

  @override
  String get pageDirectionLeftSubtitle =>
      'Left click / Left arrow key moves to the next page';

  @override
  String get pageDirectionRightTitle => 'Next Page on the Right';

  @override
  String get pageDirectionRightSubtitle =>
      'Right click / Right arrow key moves to the next page';

  @override
  String get sidebarPositionSection => 'Sidebar Position';

  @override
  String get sidebarPositionLeft => 'Left';

  @override
  String get sidebarPositionRight => 'Right';

  @override
  String get tabBarPositionSection => 'Tab Bar Position';

  @override
  String get tabBarPositionTop => 'Top (Horizontal Tabs)';

  @override
  String get tabBarPositionLeft => 'Left Edge (Vertical Tabs)';

  @override
  String get tabBarPositionRight => 'Right Edge (Vertical Tabs)';

  @override
  String get tabBarPositionOuterEdgeHint =>
      'When using vertical tabs on the same side as the sidebar, choose which one sits on the outer edge (screen side)';

  @override
  String get outerEdgeVerticalTabs => 'Vertical Tabs on the Outside';

  @override
  String get outerEdgeSidebar => 'Sidebar on the Outside';

  @override
  String get outerEdgeSidebarSubtitle =>
      'Maximising the sidebar moves the vertical tabs inward to make room';

  @override
  String get fullscreenBehaviorSection => 'Fullscreen Timing';

  @override
  String get fullscreenOnViewerOnly => 'Only While Reading a Book';

  @override
  String get fullscreenOnViewerOnlySubtitle =>
      'Shows a normal window while browsing shelves, etc.';

  @override
  String get fullscreenAlwaysOnLaunch => 'Always Fullscreen from Launch';

  @override
  String get launchTabSection => 'Startup Tab';

  @override
  String get launchTabResumeLastBook => 'Reopen the Tab You Were Last Reading';

  @override
  String get launchTabAlwaysLibrary => 'Always Start from the Top Page';

  @override
  String get launchTabAlwaysLibrarySubtitle =>
      'Reading progress is kept regardless of this setting';

  @override
  String get settingsFavoritesOpenModeSection =>
      'Settings / Favourites Icon Behaviour';

  @override
  String get openModeNewTabSubtitle =>
      'Switches to the existing tab if one is already open';

  @override
  String get openModeToggleInPlace => 'Switch Within the Current Tab';

  @override
  String get openModeToggleInPlaceSubtitle =>
      'Tapping the icon again returns to the page you were viewing before';

  @override
  String get middleClickSection => 'When Opening a New Tab with Middle-Click';

  @override
  String get middleClickSwitchToNewTab => 'Automatically Switch to the New Tab';

  @override
  String get middleClickStayOnCurrentTab => 'Stay on the Current Tab';

  @override
  String get middleClickStayOnCurrentTabSubtitle =>
      'The new tab opens in the background';

  @override
  String get mobileNavIconsSection => 'Navigation Popup Icons';

  @override
  String get mobileNavIconsHint =>
      'Unchecked icons are tucked into the menu on the right of the popup. Drag to reorder';

  @override
  String get themeSection => 'Theme';

  @override
  String get themeSystem => 'Follow System Setting';

  @override
  String get themeLight => 'Light Mode';

  @override
  String get themeDark => 'Dark Mode';

  @override
  String get languageSection => 'Language';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageEnglish => 'English';
}
