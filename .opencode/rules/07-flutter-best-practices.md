# Flutter Best Practices for Production Apps

**Reference guide for offline-first, zero-backend Flutter apps.** 

This document contains all architectural patterns, performance rules, and exact values for Flutter 3.41.x / Dart 3.11.x development.

---

## 1. Widget Architecture

### StatelessWidget is Your Default
- Use `StatefulWidget` **only** for internal mutable state (animations, form input, toggles) or lifecycle methods
- `StatelessWidget` is cheaper — no State object allocation, no lifecycle overhead
- **Always use `const` constructors** on immutable widgets
- Const widgets are canonical instances — identical const objects share single memory allocation
- Const can reduce widget rebuilds by **up to 70%**, cutting frame times from 16ms to under 8ms

```dart
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      const Text('Static Header'),   // Skipped on rebuild
      const SizedBox(height: 16),    // Skipped on rebuild
      Text('Balance: \$$_balance'),  // Rebuilt (dynamic data)
    ],
  );
}
```

### Extract Widget Classes, Never Helper Methods
**NEVER** use `buildX()` helper methods. The Flutter team explicitly recommends separate Widget classes:

```dart
// ✅ CORRECT: Separate widget class with const constructor
class AccountHeader extends StatelessWidget {
  const AccountHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [const Icon(Icons.account_circle), const Text('Account')]);
  }
}

// ❌ ANTI-PATTERN: Helper method in parent
Widget _buildHeader() => Row(children: [Icon(Icons.account_circle), Text('Account')]);
```

**Why:** Helper methods are called every rebuild, share parent's BuildContext, and cannot be marked `const`.

### Widget Tree Depth
- Keep at **5-7 levels of nesting** maximum
- Beyond this, layout passes become expensive (especially intrinsic sizing which traverses ALL children)
- Break complex widgets into focused sub-widgets through composition

### Keys — Use Sparingly and Correctly

| Key type | Use when | Example |
|----------|----------|---------|
| **ValueKey** | Widget has unique stable value | `ValueKey(transaction.id)` in list |
| **ObjectKey** | Identity based on complex object | `ObjectKey(account)` |
| **UniqueKey** | Force widget to be treated as new | Animation reset, force rebuild |
| **GlobalKey** | Access widget state externally | `GlobalKey<FormState>` for validation |

**NEVER use index as key in dynamic lists** — reordering associates wrong state with wrong data.
**NEVER construct UniqueKey inside build()** — creates new key every frame.

### State Management for Offline-First Apps

**Recommended:** Riverpod or BLoC
- **Riverpod**: Type-safe, context-free, excellent async support with `AsyncNotifier`, `autoDispose`
- **BLoC**: Enterprise standard — `hydrated_bloc` provides built-in state persistence to disk

**Legacy (avoid for new projects):** Provider

---

## 2. Responsive Sizing

### Performance-Critical: Use Specific MediaQuery Accessors

**ALWAYS** use these specific methods (rebuild only when that property changes):
- `MediaQuery.sizeOf(context)` — only rebuilds on size change
- `MediaQuery.paddingOf(context)`
- `MediaQuery.viewInsetsOf(context)`
- `MediaQuery.textScalerOf(context)` — Flutter 3.16+

**NEVER** use `MediaQuery.of(context).size` — triggers rebuilds for ANY MediaQueryData change.

### Touch Targets
- Android: **48×48dp minimum**
- iOS: **44×44pt minimum**
- Material 3 widgets default to 48dp

### Text Sizes
- Body text minimum: **14dp** (bodyMedium)
- Body text preferred: **16dp** (bodyLarge)

### Padding Grid
Use multiples of **4dp**: 4, 8, 12, 16, 20, 24, 32, 48, 64

- Compact screens: **16dp margins**, **8dp gutters**
- Medium screens (600dp+): **24-32dp margins**
- Expanded screens (840dp+): **32dp+ margins**

### Material 3 Window Size Classes

| Class | Width | Typical device | Columns |
|-------|-------|---------------|---------|
| Compact | 0-599dp | Phones | 4 |
| Medium | 600-839dp | Foldables, small tablets | 8 |
| Expanded | 840-1199dp | Tablets, laptops | 12 |
| Large | 1200-1599dp | Desktops | 12 |
| Extra-Large | 1600dp+ | Large desktops | 12 |

**NEVER check device type** — check actual window width (apps run in split-screen, PIP, resizable windows).

### Layout Widget Decision Tree

- Fixed known size → `SizedBox(width: 100, height: 50)`
- Min/max constraints → `ConstrainedBox`
- Fill remaining space in Row/Column → `Expanded`
- Can shrink in Row/Column → `Flexible(fit: FlexFit.loose)`
- Fractional parent size → `FractionallySizedBox(widthFactor: 0.8)`
- Fixed aspect ratio → `AspectRatio(aspectRatio: 16/9)`

**Expanded** forces tight filling; **Flexible** allows loose shrinking.

### SafeArea Rules
- **Use** when content is body of Scaffold without AppBar
- **Use** when content could be obscured by notches/status bars/home indicators
- **Not needed** inside Scaffold with AppBar (handles top safe area)
- SafeArea is nestable — child SafeAreas detect parent padding

### Text Scaling
**NEVER override textScaler** — respect user accessibility settings.
- ~25% of users increase font size
- Use `MediaQuery.textScalerOf(context)` (Flutter 3.16+)
- Test at 1.0x, 1.5x, 2.0x, and maximum scale
- Use `Flexible`/`Expanded` for text containers

### Overflow Prevention
| Problem | Solution |
|---------|----------|
| Hardcoded text heights | Remove fixed heights, use `Flexible`/`Expanded` |
| Row with too many children | Use `Wrap` or make children `Flexible` |
| Column in unbounded height | Wrap in `SingleChildScrollView` or use `ListView` |
| Long text | Add `overflow: TextOverflow.ellipsis` with `Expanded` parent |
| Images | Use `BoxFit.cover`/`contain` |

---

## 3. Navigation

### GoRouter (Recommended)
- Still the right choice despite maintenance mode (feature-complete, battle-tested)
- Use `StatefulShellRoute` for persistent bottom navigation

### PopScope (Replaced WillPopScope)

WillPopScope was deprecated in Flutter 3.12. **Always use PopScope:**

```dart
PopScope(
  canPop: _hasSavedChanges,
  onPopInvokedWithResult: (bool didPop, Object? result) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    final shouldPop = await _showConfirmDialog(context);
    if (shouldPop ?? false) navigator.pop();
  },
  child: Scaffold(/* form content */),
)
```

### Persistent Bottom Navigation

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(index,
          initialLocation: index == navigationShell.currentIndex),
        items: [/* tab items */],
      ),
    );
  },
  branches: [
    StatefulShellBranch(routes: [
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
    ]),
  ],
)
```

### Predictive Back (Android)
- Default since Flutter 3.38 (November 2025)
- `PredictiveBackPageTransitionsBuilder` replaced `ZoomPageTransitionsBuilder`
- WillPopScope **completely breaks predictive back** — migration to PopScope is mandatory

### Edge-to-Edge (Android 16+ API 36+)
- Edge-to-edge is **mandatory** and cannot be opted out
- `statusBarColor` and `systemNavigationBarColor` will no longer work
- Plan apps for edge-to-edge now

---

## 4. Performance

### ListView.builder is Mandatory
- **NEVER** use `ListView` for lists over ~20 items
- ListView creates ALL children in memory
- ListView.builder lazily constructs only visible widgets
- Always specify `itemExtent` or `prototypeItem` for fixed-height items

### Isolate Threshold: 16ms
Use `Isolate.run()` for one-off heavy tasks:
- Parsing JSON blobs over 1MB
- Image processing
- Sorting 10,000+ objects
- Cryptographic operations

**NEVER use isolates for I/O-bound work** — use async/await instead.

### Frame Budgets
- **60Hz**: ~16.67ms per frame
- **120Hz**: ~8.33ms per frame
- Jank rate above **1% is noticeable**
- Jank rate above **5% is unsatisfactory**

**Always profile in profile mode on physical device** — debug mode uses JIT and expensive assertions.

### RepaintBoundary
Wrap frequently-animating widgets in RepaintBoundary to create separate compositing layer:
- Use for: spinners, progress bars, tickers
- Don't wrap every widget — adds GPU memory overhead
- Verify with DevTools "Highlight repaints"

### Impeller
- Default on iOS since Flutter 3.16+
- Available on Android
- Pre-compiles all shaders at build time (eliminates runtime jank)

### Release Build Flags

```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=./debug-info/
```

- `--split-debug-info`: Removes debug symbols, dramatically reduces size
- `--obfuscate`: Renames Dart symbols (reverse engineering protection)
- `--split-per-abi`: Separate APKs per architecture (30-40% size reduction)
- AAB reduces download size up to **50%** vs universal APK

---

## 5. Error Handling

### Three-Layer Defense

```dart
Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kReleaseMode) errorReporter.recordFlutterError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      errorReporter.recordError(error, stack);
      return true;
    };

    ErrorWidget.builder = (details) => kDebugMode
        ? ErrorWidget(details.exception)
        : const Scaffold(body: Center(child: Text('Something went wrong')));

    runApp(const MyApp());
  }, (error, stack) {
    errorReporter.recordError(error, stack);
  });
}
```

### Common Crash Patterns and Fixes

**setState() after dispose():**
```dart
// Always check mounted before setState after async gaps
if (mounted) setState(() { ... });

// Better: cancel source in dispose()
@override
void dispose() {
  _timer?.cancel();
  super.dispose();
}
```

**Null check operator on null value:**
```dart
// ❌ Never use ! on external data
final value = prefs.getString('key')!;

// ✅ Use null-aware operators
final value = prefs.getString('key') ?? 'default';
```

**Deactivated widget ancestor lookup:**
```dart
onPressed: () async {
  final navigator = Navigator.of(context);  // Capture BEFORE await
  await doSomething();
  if (mounted) navigator.pop();
}
```

---

## 6. Lifecycle Management

### AppLifecycleListener (Flutter 3.13+)

**Replaces WidgetsBindingObserver** as preferred API:

```dart
late final AppLifecycleListener _listener;

@override
void initState() {
  super.initState();
  _listener = AppLifecycleListener(
    onPause: _saveUnsavedData,
    onResume: _refreshData,
    onInactive: _pauseMediaPlayback,
    onDetach: _cleanup,
  );
}

@override
void dispose() {
  _listener.dispose();
  super.dispose();
}
```

### Dispose Order (Critical)

```dart
@override
void dispose() {
  _timer?.cancel();                           // 1. Stop callbacks
  _subscription?.cancel();                    // 2. Cancel streams
  WidgetsBinding.instance.removeObserver(this); // 3. Remove observers
  _animationController.dispose();             // 4. Dispose controllers
  _textController.dispose();
  _focusNode.dispose();
  _lifecycleListener.dispose();
  super.dispose();                            // 5. ALWAYS last
}
```

---

## 7. Local Storage

### Database Hierarchy

1. **Drift** (Recommended default) — type-safe SQL, robust migrations, reactive streams, SQLCipher encryption
2. **Isar** — **ABANDONED** by author — do not use
3. **Hive** — **UNMAINTAINED** — use hive_ce (Community Edition) if needed
4. **ObjectBox** — Best raw performance, built-in sync, but commercial

### SharedPreferences Limits
- Keep under **~1MB total**, ideally few KB
- Supported: `int`, `double`, `bool`, `String`, `List<String>`
- **NEVER** store passwords, tokens, or complex objects
- Use `SharedPreferencesWithCache` or `SharedPreferencesAsync` (legacy API deprecated)

### Schema Migration Pattern

```dart
Database db = await openDatabase(path, version: 3,
  onCreate: (db, version) async {
    var batch = db.batch();
    _createLatestSchema(batch);
    await batch.commit();
  },
  onUpgrade: (db, oldVersion, newVersion) async {
    var batch = db.batch();
    if (oldVersion < 2) _migrateV1toV2(batch);
    if (oldVersion < 3) _migrateV2toV3(batch);
    await batch.commit();
  },
);
```

### Three-Layer Encryption for Finance Data

1. **Layer 1 (secrets)**: `flutter_secure_storage` — RSA-OAEP + AES-GCM (Android), Keychain (iOS)
2. **Layer 2 (database)**: SQLCipher via `sqflite_sqlcipher` — AES-256 full-database encryption
3. **Layer 3**: Store encryption key in flutter_secure_storage (never SharedPreferences or hardcoded)

---

## 8. Material 3 Theming

### ColorScheme.fromSeed

```dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    ),
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.dark,
    ),
  ),
  themeMode: ThemeMode.system,
)
```

Material 3 is default since Flutter 3.16+.

### Typography Tokens

| Token | Size | Weight |
|-------|------|--------|
| displayLarge | 57sp | 400 |
| displayMedium | 45sp | 400 |
| displaySmall | 36sp | 400 |
| headlineLarge | 32sp | 400 |
| headlineMedium | 28sp | 400 |
| headlineSmall | 24sp | 400 |
| titleLarge | 22sp | 400 |
| titleMedium | 16sp | 500 |
| titleSmall | 14sp | 500 |
| bodyLarge | 16sp | 400 |
| bodyMedium | 14sp | 400 |
| bodySmall | 12sp | 400 |
| labelLarge | 14sp | 500 |
| labelMedium | 12sp | 500 |
| labelSmall | 11sp | 500 |

### Shape Scale (Border Radius)

- Extra Small: **4dp** (chips, small buttons)
- Small: **8dp**
- Medium: **12dp** (cards, dialogs)
- Large: **16dp** (FAB)
- Extra Large: **28dp** (bottom sheets, search bars)
- Full: **50%** (circles/stadiums)

### Accessing Theme

```dart
// ✅ CORRECT
final color = Theme.of(context).colorScheme.primary;
final style = Theme.of(context).textTheme.bodyLarge;

// ❌ NEVER hardcode
color: Color(0xFF6750A4),
```

---

## 9. Testing

### Coverage Targets
- Minimum viable: **60-70%**
- Good (CI enforced): **80%**
- Excellent: **90%+**

### Widget Tests

```dart
testWidgets('Transaction list shows items', (tester) async {
  await tester.pumpWidget(MaterialApp(home: TransactionList(items: mockItems)));
  expect(find.text('Grocery'), findsOneWidget);
  await tester.tap(find.byIcon(Icons.delete));
  await tester.pump();
  expect(find.text('Grocery'), findsNothing);
});
```

### Mocking SharedPreferences

```dart
test('reads stored preference', () async {
  SharedPreferences.setMockInitialValues({'theme': 'dark'});
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getString('theme'), 'dark');
});
```

---

## 10. Anti-Patterns to Avoid

### ❌ FutureBuilder Without Caching (Critical)

```dart
// ❌ CRITICAL: New Future every rebuild
Widget build(BuildContext context) =>
  FutureBuilder(future: api.fetchData(), builder: ...);

// ✅ Cache in initState
late final Future<Data> _dataFuture;
@override
void initState() { 
  super.initState(); 
  _dataFuture = api.fetchData(); 
}
```

### ❌ Nested SingleChildScrollViews
Replace with `CustomScrollView` + Slivers or `NestedScrollView`.

### ❌ Business Logic in Widgets
Follow MVVM: Widgets describe UI, ViewModels handle logic, Repositories are source of truth.

### ❌ setState in Large Widgets
Isolate dynamic parts into separate small StatefulWidgets.

### ❌ Hardcoded Colors and Sizes
Always use `Theme.of(context)`.

---

## Summary: Rules That Matter Most

1. **const constructors everywhere** — up to 70% fewer rebuilds
2. **separate widget classes over helper methods** — independent rebuild scopes
3. **Drift for structured offline data with SQLCipher** — type-safe, encrypted
4. **three-layer error handling** — FlutterError.onError + PlatformDispatcher + runZonedGuarded
5. **GoRouter with StatefulShellRoute** for navigation
6. **Riverpod or BLoC with hydrated persistence** for state management
7. **ListView.builder for lists over 20 items**
8. **Never use ! on external data**
9. **Every controller needs dispose**
10. **Every async gap needs mounted check**
11. **Every list item needs stable ValueKey**

**Release builds:** Use `--obfuscate --split-debug-info` and ship App Bundles exclusively.

**Test at 80%+ coverage** on physical devices in profile mode.